# Daemon lifecycle

## Design overview

`sandbox-broker` is a long-lived daemon. The lifecycle has three
non-trivial pieces: **daemonize-by-default** (so `start` returns
immediately), **capability probe at boot** (so misconfigured deployments
fail fast at start, not at first hit), and **cleanup-stack on shutdown**
(so the socket / PID / log are torn down deterministically).

Key decisions:

- **Default to daemon, not foreground**. `sandbox-broker start` is
  the one-step UX (mirrors `portless proxy start`); systemd, debug,
  and tests use `start --foreground`.
- **Fork via self-reexec, not the `daemonize` crate**. The agent's
  tokio runtime is started after the fork in the foreground child,
  avoiding the fork-while-multithreaded class of bugs.
- **PID file with O_EXCL create**. Two `start` invocations in parallel
  cleanly fail one of them with "broker already running".
- **Cleanup stack pattern (LIFO + priority slot)** borrowed from
  [E2B](./refs/e2b.md#failure-modes). Resources register their
  teardown closure on construction; SIGTERM unwinds the stack.
- **Capability probe runs once at start**, result cached in
  `.sandbox/capabilities.toml`. The doctor subcommand re-runs it on
  demand.

![Daemon state machine: spawn → serve → cleanup](./diagrams/lifecycle-state.svg)

## `start` flow

```
sandbox-broker start [--foreground]
  ├─ Parse CLI args, resolve project root
  ├─ Load policy.toml (hard-fail if missing/invalid)
  ├─ Run capability probe
  │   ├─ Check Landlock kernel ABI (landlock_create_ruleset(0,0,VER))
  │   ├─ Check bwrap presence in PATH
  │   ├─ Check seccomp availability (uname / /proc/sys/kernel/seccomp)
  │   └─ Write .sandbox/capabilities.toml
  ├─ If runtime.require_landlock and Landlock unavailable: ABORT
  ├─ If runtime.require_bwrap and bwrap missing: ABORT
  ├─ If --foreground OR runtime.daemonize == false:
  │     Continue inline as the daemon
  ├─ Else (default):
  │     spawn child = self_path() with [start, --foreground, project_dir]
  │     redirect child stdout/stderr to .sandbox/broker.log (append)
  │     write child.pid to .sandbox/broker.pid (O_EXCL)
  │     unlock if write failed → broker already running → exit 1
  │     parent exits 0
  └─ (in foreground child / inline branch)
      Initialize tokio runtime
      Build Broker { policy, session, learning?, audit_buffer }
      Bind UDS at .sandbox/broker.sock
      Install signal handlers (SIGTERM, SIGINT, SIGHUP)
      Register cleanup stack (LIFO):
        - PID file unlink
        - Socket unlink
        - Log file flush + close
        - Audit buffer final flush
      Serve until signal
      Run cleanup stack
      Exit 0
```

### Self-reexec

```rust
fn spawn_self_foreground(args: &[OsString]) -> io::Result<Child> {
    let exe = std::env::current_exe()?;
    let log_path = base.join(".sandbox/broker.log");
    let log = OpenOptions::new()
        .append(true).create(true).open(&log_path)?;
    let log_clone = log.try_clone()?;

    Command::new(exe)
        .arg("start").arg("--foreground")
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::from(log))
        .stderr(Stdio::from(log_clone))
        // setsid so the child detaches from the controlling terminal
        .pre_exec(|| {
            unsafe { libc::setsid() };
            Ok(())
        })
        .spawn()
}
```

Avoiding the `daemonize` crate's fork-while-multithreaded issues:
tokio runtime is built **inside** the foreground child, after `fork`
+ `exec` (`spawn` does both), so there's no live thread state across
the boundary.

### PID file

```rust
fn write_pid_file(path: &Path, pid: u32) -> io::Result<()> {
    let mut f = OpenOptions::new()
        .create_new(true)         // O_EXCL — fails if exists
        .write(true)
        .open(path)?;
    writeln!(f, "{}", pid)?;
    Ok(())
}
```

If `create_new` fails with `EEXIST`, two cases:

1. The recorded PID is alive and is a `sandbox-broker` process (`/proc/<pid>/comm`):
   broker already running → `start` exits 1 with a clear message.
2. The recorded PID is dead or is something else:
   stale PID file → `start` removes it and retries.

This is "stale-detection" `O_EXCL` — borrowed from standard daemon
patterns and from [Daytona's
`recover.go`](./refs/daytona.md#failure-modes).

## `stop` flow

```
sandbox-broker stop
  ├─ Read .sandbox/broker.pid
  ├─ If file missing or empty: print "broker is not running", exit 0
  ├─ kill(pid, SIGTERM)
  ├─ Wait up to 5s for socket to disappear
  ├─ If still running: kill(pid, SIGKILL)
  └─ Exit 0
```

The daemon's signal handler does the real work — `stop` is a thin
wrapper around `kill` plus a timeout-bounded wait.

## Signal handling

The daemon installs handlers for:

| Signal | Action |
|---|---|
| `SIGTERM` | Graceful: stop accepting, drain in-flight RPCs (max 2s), run cleanup stack, exit 0 |
| `SIGINT` (Ctrl-C in foreground mode) | Same as SIGTERM |
| `SIGHUP` | Reload policy.toml. If reload fails, log error, keep running on old policy. |
| `SIGCHLD` | Default (we don't fork sub-broker children) |

Implementation uses `tokio::signal::unix::signal` and a single
`tokio::select!` over the listener and signals.

## Cleanup-stack pattern

Borrowed from [E2B's `cleanup`](./refs/e2b.md#notable-design-ideas):

```rust
pub struct Cleanup {
    stack: Mutex<Vec<Box<dyn FnOnce() + Send>>>,
    priority: Mutex<Option<Box<dyn FnOnce() + Send>>>, // runs first
}

impl Cleanup {
    pub fn add(&self, f: impl FnOnce() + Send + 'static) {
        self.stack.lock().unwrap().push(Box::new(f));
    }
    pub fn add_priority(&self, f: impl FnOnce() + Send + 'static) {
        let mut slot = self.priority.lock().unwrap();
        assert!(slot.is_none(), "priority slot already taken");
        *slot = Some(Box::new(f));
    }
    pub fn run(self) {
        if let Some(p) = self.priority.into_inner().unwrap() { p(); }
        let mut s = self.stack.into_inner().unwrap();
        while let Some(f) = s.pop() { f(); }
    }
}
```

Registration during startup (LIFO unwind):

```rust
// stack stage 0 (runs last)
cleanup.add(|| audit_buffer.flush());
// stack stage 1
cleanup.add(|| log_file.flush());
// stack stage 2
cleanup.add(|| std::fs::remove_file(&pid_path).ok());
// stack stage 3 (runs first non-priority)
cleanup.add(|| std::fs::remove_file(&sock_path).ok());

// priority slot (runs FIRST regardless of stack order):
cleanup.add_priority(|| listener.shutdown());  // stop accepting first
```

The priority slot guarantees socket-stop-accepting runs before any
unlinks; clients that try to connect during teardown get
`ECONNREFUSED` (passing the hook's fail-open path) rather than
"connected then disconnected mid-RPC".

## Capability probe

Runs at every `start` and writes:

```toml
# .sandbox/capabilities.toml (auto-generated, do not edit)
probed_at = "2026-04-30T12:00:00Z"
kernel_version = "6.18.24"

[landlock]
available = true
abi_version = 5
features = ["fs.refer", "fs.truncate", "net.bind", "net.connect"]

[bwrap]
available = true
path = "/run/current-system/sw/bin/bwrap"
version = "0.10.0"

[seccomp]
available = true
```

Probe implementation:

```rust
fn probe_landlock() -> LandlockCapability {
    let abi = unsafe {
        libc::syscall(
            libc::SYS_landlock_create_ruleset,
            std::ptr::null::<()>(),
            0usize,
            LANDLOCK_CREATE_RULESET_VERSION,
        )
    };
    if abi < 0 {
        return LandlockCapability { available: false, .. };
    }
    LandlockCapability {
        available: true,
        abi_version: abi as u32,
        features: features_for_abi(abi as u32),
    }
}

fn probe_bwrap() -> BwrapCapability {
    let path = which("bwrap").ok();
    let version = path.as_ref().and_then(|p| {
        let out = Command::new(p).arg("--version").output().ok()?;
        // parse "bubblewrap 0.10.0"
    });
    BwrapCapability { available: path.is_some(), path, version }
}
```

The doctor subcommand re-runs the probe and pretty-prints the result:

```
$ sandbox-broker doctor
project:  /home/user/project
kernel:   Linux 6.18.24

Landlock: available (ABI v5)
  features: fs.refer fs.truncate net.bind net.connect
bwrap:    available (/run/current-system/sw/bin/bwrap, v0.10.0)
seccomp:  available

policy.toml requires: (none beyond core)
broker:   running (pid 12345)
```

Borrowed from [Windmill's
boot probe](./refs/windmill.md#notable-design-ideas) and Codex's
runtime selection.

## Hard-fail rules

These conditions cause `start` to abort with a non-zero exit and a clear
error message (no fall-back to "weak default"):

| Condition | Error |
|---|---|
| `policy.toml` missing | `policy.toml not found at <path>; run \`sandbox-broker init\`` |
| `policy.toml` is invalid TOML | `invalid TOML at <line>:<col>: <message>` |
| `policy.toml` schema mismatch | `policy schema error: <details>` |
| `policy.toml` has unmatchable `examples` | `rule '<pattern>': example '<argv>' does not match` |
| `policy.toml` has matching `not_examples` | `rule '<pattern>': not_example '<argv>' should not match but does` |
| `runtime.require_landlock = true` and Landlock unavailable | `runtime.require_landlock is true but Landlock kernel support is missing (need v3+)` |
| `runtime.require_bwrap = true` and bwrap missing | `runtime.require_bwrap is true but bwrap binary is not in PATH` |
| `runtime.wrap_allowed_bash = true` and Landlock unavailable | `runtime.wrap_allowed_bash requires Landlock; abort` |
| Stale PID file with live broker | `broker already running (pid X); use \`sandbox-broker stop\`` |
| Socket bind fails (file exists, EADDRINUSE) | `socket already in use; the previous broker may have crashed; remove .sandbox/broker.sock and retry` |

The current broker's behaviour of falling back to `Policy::default()`
(deny-all) is **deliberately removed**. "Broker started fine but is
denying everything" is the worst possible UX.

## Working directory and project root

The daemon's working directory is set to `<base-repo-root>/.sandbox/`
on start. All file paths in the design (`broker.sock`, `broker.pid`,
`broker.log`, `policy.toml`, `session.toml`, `audit.log`,
`capabilities.toml`, `learned.toml`) are relative to this directory.

When invoked from a worktree, the daemon resolves the base repo via
`git rev-parse --git-common-dir` + `..` and ignores the worktree
identity. One broker per base repo, all worktrees share it.

When invoked outside a git repo, `<base>` is `cwd` itself.

---

## Key design decisions

- **Daemonize-by-default**. `sandbox-broker start` is the one-step UX
  the user types. Foreground mode is for systemd / debug / tests
  (`--foreground`). Mirrors [portless](./refs/synthesis.md#daemonize)
  and [agent-browser]'s defaults.

- **Self-reexec rather than `daemonize` crate**. The fork happens
  before tokio is initialized; the foreground child is the only place
  with a multi-threaded runtime. No `fork()` while threads are alive.

- **PID file with O_EXCL plus stale detection**. Standard daemon
  pattern, prevents the "two daemons fighting over a socket" mode the
  current broker exhibited.

- **Cleanup stack borrowed from E2B**. Registration-order LIFO unwind +
  priority slot for the listener-stop-accepting step. Eliminates the
  "leaked socket / PID file" class of bugs.

- **Capability probe at boot, cached**. Mirrors
  [Windmill's NSJail probe](./refs/windmill.md). Failing fast at start
  is much better UX than failing on first allowed-Bash hit.

- **Hard-fail on invalid policy or unmet capability requirement**.
  Borrowed from sandbox-runtime's anti-pattern: silent fall-back to
  permissive default is dangerous; loud failure is the only safe move.

- **Working directory is `.sandbox/`**. All daemon-state files live
  in one place that's already conventional for the broker.
