mod broker;
mod learning;
mod matcher;
mod operation;
mod persist;
mod policy;
mod server;
mod session;
mod subagent;
mod verdict;
mod worktree;

use broker::{Broker, Mode};
use policy::Policy;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn resolve_project(args: &[&str]) -> PathBuf {
    args.iter()
        .find(|a| !a.starts_with('-'))
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::current_dir().unwrap())
}

fn resolve_base(project_dir: &Path) -> PathBuf {
    worktree::resolve_base_repo(project_dir)
}

fn sandbox_dir(base: &Path) -> PathBuf {
    base.join(".sandbox")
}

fn policy_path(base: &Path) -> PathBuf {
    sandbox_dir(base).join("policy.toml")
}

fn sock_path(base: &Path) -> PathBuf {
    server::socket_path(&sandbox_dir(base))
}

fn is_broker_alive(base: &Path) -> Option<bool> {
    let sock = sock_path(base);
    if sock.exists() {
        Some(std::os::unix::net::UnixStream::connect(&sock).is_ok())
    } else {
        None
    }
}

fn print_help() {
    eprintln!(
        "\
sandbox-broker {VERSION} - sandbox permission broker for AI coding agents

Usage: sandbox-broker <command> [options]

Commands:
  start [dir]           Start the broker daemon
  stop [dir]            Stop the broker daemon
  status [dir]          Show broker and policy status
  init [dir]            Create .sandbox/policy.toml from template
  learn [dir]           Start in learning mode (record ops, generate policy)
  policy [dir]          Show loaded policy details
  log [dir]             Show session grants

Options:
  --version, -V         Show version
  --help, -h            Show this help

Environment:
  SANDBOX_BROKER_SOCK   Override broker socket path
  SANDBOX_BROKER_ENABLED  Set to 0 to bypass hooks (default: 1)
  RUST_LOG              Logging level (e.g. sandbox_broker=debug)

Setup:
  sandbox-broker init                    Create policy from template
  sandbox-broker start                   Start broker for current repo
  sandbox-broker status                  Check if broker is running

Workflow:
  sandbox-broker learn                   Record all ops without blocking
  sandbox-broker start                   Enforce the generated policy

  Hooks for Claude Code and Codex are installed via Nix Home Manager.
  The broker uses .sandbox/policy.toml to allow/deny agent operations."
    );
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 {
        cmd_status(&[]).map(|_| std::process::exit(0))?;
        return Ok(());
    }

    let command = args[1].as_str();
    let rest: Vec<&str> = args[2..].iter().map(|s| s.as_str()).collect();

    match command {
        "start" => cmd_start(&rest).await,
        "stop" => cmd_stop(&rest),
        "status" => cmd_status(&rest),
        "init" => cmd_init(&rest),
        "learn" => cmd_learn(&rest).await,
        "policy" => cmd_policy(&rest),
        "log" => cmd_log(&rest),
        "--version" | "-V" => {
            println!("sandbox-broker {VERSION}");
            Ok(())
        }
        "help" | "--help" | "-h" => {
            print_help();
            Ok(())
        }
        _ => {
            eprintln!("unknown command: {command}");
            eprintln!("run: sandbox-broker help");
            std::process::exit(1);
        }
    }
}

fn init_tracing() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("sandbox_broker=info".parse().unwrap()),
        )
        .init();
}

async fn cmd_start(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    init_tracing();

    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);

    if base != project_dir {
        tracing::info!(
            worktree = %project_dir.display(),
            base = %base.display(),
            "detected worktree, using base repo policy"
        );
    }

    let sdir = sandbox_dir(&base);
    let ppath = policy_path(&base);

    std::fs::create_dir_all(&sdir)?;

    let policy = if ppath.exists() {
        Policy::load(&ppath)?
    } else {
        tracing::warn!(
            "no policy.toml at {}, using empty policy (deny-all)",
            ppath.display()
        );
        tracing::warn!("run: sandbox-broker init");
        Policy::default()
    };

    tracing::info!(
        project = %base.display(),
        mode = "enforce",
        rules = policy.filesystem.read.len()
            + policy.filesystem.write.len()
            + policy.network.connect.len()
            + policy.commands.len(),
        "broker starting"
    );

    let broker = Arc::new(Broker::new(policy, &sdir, Mode::Enforce));
    let sock = server::socket_path(&sdir);
    server::serve(broker, &sock).await
}

async fn cmd_learn(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    init_tracing();

    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);
    let sdir = sandbox_dir(&base);

    std::fs::create_dir_all(&sdir)?;

    let policy = policy_path(&base);
    let policy = if policy.exists() {
        Policy::load(&policy)?
    } else {
        Policy::default()
    };

    tracing::info!(
        project = %base.display(),
        mode = "learning",
        "recording all operations (nothing blocked)"
    );

    let broker = Arc::new(Broker::new(policy, &sdir, Mode::Learning));
    let sock = server::socket_path(&sdir);
    server::serve(broker, &sock).await
}

fn cmd_stop(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);
    let sock = sock_path(&base);

    if !sock.exists() {
        eprintln!("broker is not running");
        return Ok(());
    }

    match std::os::unix::net::UnixStream::connect(&sock) {
        Ok(_stream) => {
            // TODO: send graceful shutdown signal once server supports it
            std::fs::remove_file(&sock)?;
            eprintln!("broker stopped");
        }
        Err(_) => {
            std::fs::remove_file(&sock)?;
            eprintln!("removed stale socket");
        }
    }

    Ok(())
}

fn cmd_status(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);
    let out = std::io::stdout();
    let mut w = out.lock();

    writeln!(w, "project:  {}", base.display())?;

    let ppath = policy_path(&base);
    if ppath.exists() {
        match Policy::load(&ppath) {
            Ok(p) => {
                let rules = p.filesystem.read.len()
                    + p.filesystem.write.len()
                    + p.network.connect.len()
                    + p.commands.len();
                writeln!(w, "policy:   {rules} rules loaded")?;
            }
            Err(e) => writeln!(w, "policy:   ERROR ({e})")?,
        }
    } else {
        writeln!(w, "policy:   not found (run: sandbox-broker init)")?;
    }

    match is_broker_alive(&base) {
        Some(true) => writeln!(w, "broker:   running")?,
        Some(false) => {
            writeln!(w, "broker:   stale socket")?;
            writeln!(w, "  fix: sandbox-broker stop && sandbox-broker start")?;
        }
        None => {
            writeln!(w, "broker:   not running")?;
        }
    }

    Ok(())
}

fn cmd_init(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);
    let ppath = policy_path(&base);

    if ppath.exists() {
        eprintln!("policy already exists: {}", ppath.display());
        eprintln!("edit directly or delete to re-init");
        std::process::exit(1);
    }

    let sdir = sandbox_dir(&base);
    std::fs::create_dir_all(&sdir)?;

    let template = include_str!("../examples/policy.toml");
    std::fs::write(&ppath, template)?;

    eprintln!("created: {}", ppath.display());
    eprintln!("next: edit the policy, then sandbox-broker start");

    Ok(())
}

fn cmd_policy(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);
    let ppath = policy_path(&base);

    if !ppath.exists() {
        eprintln!("no policy found (run: sandbox-broker init)");
        std::process::exit(1);
    }

    let policy = Policy::load(&ppath)?;
    let out = std::io::stdout();
    let mut w = out.lock();

    writeln!(w, "policy: {}", ppath.display())?;
    writeln!(w)?;

    if !policy.filesystem.read.is_empty() {
        writeln!(w, "filesystem.read:")?;
        for p in &policy.filesystem.read {
            writeln!(w, "  {p}")?;
        }
    }

    if !policy.filesystem.write.is_empty() {
        writeln!(w, "filesystem.write:")?;
        for p in &policy.filesystem.write {
            writeln!(w, "  {p}")?;
        }
    }

    if !policy.network.connect.is_empty() {
        writeln!(w, "network.connect:")?;
        for p in &policy.network.connect {
            writeln!(w, "  {p}")?;
        }
    }

    if !policy.network.bind.is_empty() {
        writeln!(w, "network.bind:")?;
        for b in &policy.network.bind {
            writeln!(w, "  :{b}")?;
        }
    }

    if !policy.commands.is_empty() {
        writeln!(w, "commands:")?;
        for c in &policy.commands {
            writeln!(w, "  {} [{}]", c.pattern.join(" "), c.scope)?;
        }
    }

    Ok(())
}

fn cmd_log(args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
    let project_dir = resolve_project(args);
    let base = resolve_base(&project_dir);
    let session_path = sandbox_dir(&base).join("session.toml");

    if !session_path.exists() {
        eprintln!("no session data (broker has not run yet)");
        return Ok(());
    }

    let session = session::Session::load(&session_path);
    let grants = session.granted_list();
    let out = std::io::stdout();
    let mut w = out.lock();

    if grants.is_empty() {
        writeln!(w, "no grants in current session")?;
    } else {
        writeln!(w, "session grants ({}):", grants.len())?;
        for g in grants {
            writeln!(
                w,
                "  {:?} {} [{}]",
                g.source, g.pattern, g.category
            )?;
        }
    }

    Ok(())
}
