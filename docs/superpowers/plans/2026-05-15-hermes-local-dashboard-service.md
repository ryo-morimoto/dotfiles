# Hermes Tailnet Dashboard Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the Hermes Web Dashboard automatically on `ryobox` as a Tailnet-only NixOS systemd service.

**Architecture:** Keep the upstream `services.hermes-agent` Podman container as the runtime anchor and add a separate `hermes-agent-dashboard.service` that runs `hermes dashboard` inside the existing container with `podman exec --user hermes`. Bind the dashboard to `0.0.0.0:9119` with `--insecure`, add Hermes' `web` and `pty` optional dependency groups, and open port `9119` only on the `tailscale0` firewall interface.

**Tech Stack:** NixOS module config in `hosts/ryobox/default.nix`, upstream Hermes Agent NixOS module, Podman, systemd, Hermes Web Dashboard.

---

## Source Notes

- Hermes dashboard docs: <https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard/>
- The dashboard defaults to `127.0.0.1:9119`.
- The docs warn that binding to `0.0.0.0` exposes API keys and credentials and should only be done with strong network controls.
- For this host, the accepted network control is the NixOS firewall scoped to `tailscale0`; port `9119` must not be added to global `networking.firewall.allowedTCPPorts`.
- The dashboard needs the `web` optional dependency group for FastAPI/Uvicorn.
- The in-browser Chat tab needs the `pty` optional dependency group.
- Upstream `pyproject.toml` declares:

```toml
web = ["fastapi==0.133.1", "uvicorn[standard]==0.41.0"]
pty = [
  "ptyprocess==0.7.0; sys_platform != 'win32'",
  "pywinpty==2.0.15; sys_platform == 'win32'",
]
```

## Scope

### In Scope

- Add `web` and `pty` to `services.hermes-agent.extraDependencyGroups`.
- Add `hermes-agent-dashboard.service`.
- Bind dashboard for Tailnet access.
- Open dashboard firewall access only on `tailscale0`.
- Wire dashboard lifecycle to `hermes-agent.service`.
- Update docs that currently say the dashboard is not used.
- Verify Nix evaluation and the generated systemd unit.

### Out Of Scope

- No ordinary LAN exposure.
- No global firewall exposure for port `9119`.
- No Tailscale Funnel or public internet exposure.
- No dashboard secret editing through age/agenix. The dashboard is runtime UI only.
- No upstream Hermes module patch.

## File Structure

- Modify `hosts/ryobox/default.nix`
  - Extend `services.hermes-agent.extraDependencyGroups`.
  - Add `hermes-agent-dashboard.service` under the existing `systemd.services` attrset.
- Modify `docs/agents/operating-principles.md`
  - Change the Hermes dashboard principle from "do not run" to "`tailscale0`-scoped auxiliary UI".
- Modify `docs/hermes-discord-profiles.md`
  - Add a short note that Discord remains the primary remote UI and dashboard is Tailnet-only.
- Create or modify this plan file only for planning traceability.

## Task 1: Enable Dashboard Dependency Groups

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [x] **Step 1: Update `extraDependencyGroups`**

Replace the current Hermes dependency group line:

```nix
extraDependencyGroups = [ "messaging" ];
```

with:

```nix
extraDependencyGroups = [
  "messaging"
  "web"
  "pty"
];
```

Expected surrounding block:

```nix
hermes-agent = {
  enable = true;
  addToSystemPackages = true;
  extraDependencyGroups = [
    "messaging"
    "web"
    "pty"
  ];
  settings.model.provider = "openai-codex";
  container = {
    enable = true;
    backend = "podman";
    hostUsers = [ username ];
  };
};
```

## Task 2: Add Dashboard Service

**Files:**
- Modify: `hosts/ryobox/default.nix`

- [x] **Step 1: Add service beside existing Hermes systemd services**

Inside the existing `systemd.services = ... // { ... };` attrset, add:

```nix
"hermes-agent-dashboard" = {
  description = "Hermes Agent Dashboard";
  wantedBy = [ "multi-user.target" ];
  requires = [ "hermes-agent.service" ];
  bindsTo = [ "hermes-agent.service" ];
  partOf = [ "hermes-agent.service" ];
  after = [ "hermes-agent.service" ];

  serviceConfig = {
    Type = "simple";
    ExecStart = "${pkgs.podman}/bin/podman exec --user hermes ${hermesContainerName} ${hermesContainerHermesBin} dashboard --host 0.0.0.0 --port 9119 --no-open --tui --insecure";
    Restart = "always";
    RestartSec = 5;
  };
};
```

Expected behavior:

- `hermes-agent-dashboard.service` starts on boot.
- It starts only after the `hermes-agent` container exists.
- It stops and restarts with `hermes-agent.service`.
- It restarts if `hermes dashboard` exits.
- It binds inside the host-networked Hermes container so other Tailnet devices can connect.
- The host firewall limits port `9119` to `tailscale0`.

- [x] **Step 2: Open firewall only on `tailscale0`**

Do not add `9119` to global firewall ports:

```nix
networking.firewall.allowedTCPPorts
```

Expected `tailscale0` firewall block:

```nix
firewall.interfaces.tailscale0.allowedTCPPorts = [
  80
  443
  9119
];
```

## Task 3: Update Docs

**Files:**
- Modify: `docs/agents/operating-principles.md`
- Modify: `docs/hermes-discord-profiles.md`

- [x] **Step 1: Update operating principle**

Replace the Hermes principle line:

```markdown
- Hermes Agent は dashboard を常駐公開せず、Discord profile gateway を primary UI とする。Runtime service は managed mode を維持し、profile directory / config は Nix activation、Discord env は agenix、Codex auth は profile runtime state として管理する。
```

with:

```markdown
- Hermes Agent は Discord profile gateway を primary remote UI とし、dashboard は `tailscale0` 限定公開の補助 UI として運用する。Runtime service は managed mode を維持し、profile directory / config は Nix activation、Discord env は agenix、Codex auth は profile runtime state として管理する。
```

- [x] **Step 2: Add dashboard note to Hermes Discord docs**

Add this section before `## Checks` in `docs/hermes-discord-profiles.md`:

```markdown
## Local Dashboard

The Hermes dashboard runs as `hermes-agent-dashboard.service` and binds to `0.0.0.0:9119` with `--insecure`, but the
host firewall opens port `9119` only on `tailscale0`. It is a Tailnet-only maintenance UI; Discord profile gateways
remain the primary remote UI. Do not add `9119` to global firewall ports or expose the dashboard to the ordinary LAN,
because the dashboard can read and write Hermes runtime configuration and credentials.
```

## Task 4: Verify Nix Evaluation

**Files:**
- No additional files.

- [x] **Step 1: Format Nix**

Run:

```bash
nixfmt hosts/ryobox/default.nix
```

Expected: command exits 0.

- [x] **Step 2: Check dependency groups**

Run:

```bash
nix eval --json '.#nixosConfigurations.ryobox.config.services.hermes-agent.extraDependencyGroups'
```

Expected output:

```json
["messaging","web","pty"]
```

- [x] **Step 3: Check dashboard ExecStart**

Run:

```bash
nix eval --raw '.#nixosConfigurations.ryobox.config.systemd.services."hermes-agent-dashboard".serviceConfig.ExecStart'
```

Expected output contains:

```text
podman exec --user hermes hermes-agent /data/current-package/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open --tui --insecure
```

- [x] **Step 4: Check firewall exposes dashboard only on Tailnet**

Run:

```bash
nix eval --json '.#nixosConfigurations.ryobox.config.networking.firewall.interfaces.tailscale0.allowedTCPPorts'
```

Expected output:

```json
[80,443,9119]
```

- [x] **Step 5: Run flake check**

Run:

```bash
nix flake check
```

Expected: `all checks passed!`

## Task 5: Runtime Verification After Rebuild

**Files:**
- No additional files.

- [ ] **Step 1: Rebuild**

Run:

```bash
sudo nixos-rebuild switch --flake .
```

Expected: rebuild succeeds and systemd loads `hermes-agent-dashboard.service`.

- [ ] **Step 2: Restart Hermes container anchor**

Run:

```bash
sudo systemctl restart hermes-agent.service
```

Expected: `hermes-agent-dashboard.service`, `hermes-gateway-personal.service`, and `hermes-gateway-work.service` restart through their `PartOf=hermes-agent.service` relationship.

- [ ] **Step 3: Check services**

Run:

```bash
systemctl is-active hermes-agent.service hermes-agent-dashboard.service hermes-gateway-personal.service hermes-gateway-work.service
```

Expected output:

```text
active
active
active
active
```

- [ ] **Step 4: Check bind address**

Run:

```bash
ss -ltnp | rg ':9119'
```

Expected output contains `0.0.0.0:9119`.

- [ ] **Step 5: Check HTTP response**

Run:

```bash
curl -I http://127.0.0.1:9119/
```

Expected: an HTTP response is returned from the dashboard process.

From another Tailnet device, open:

```text
http://ryobox:9119/
```

Expected: the dashboard UI loads over Tailscale. The same port must not be reachable from the ordinary LAN address.

- [ ] **Step 6: Check logs**

Run:

```bash
journalctl -u hermes-agent-dashboard.service -n 80 --no-pager
```

Expected: no missing FastAPI/Uvicorn dependency error.

## Commit

Commit only the dashboard-related Nix/doc changes and keep unrelated working tree changes out of the commit unless the user explicitly asks to include them.

```bash
git add hosts/ryobox/default.nix docs/agents/operating-principles.md docs/hermes-discord-profiles.md docs/superpowers/plans/2026-05-15-hermes-local-dashboard-service.md
git commit -m "feat(hermes): expose dashboard on tailnet"
```

## Self-Review

- Spec coverage: The plan covers dashboard dependencies, systemd lifecycle, Tailnet-only exposure, documentation, and verification.
- Placeholder scan: No placeholders remain.
- Type consistency: Uses existing local names `hermesContainerName` and `hermesContainerHermesBin`, and existing service anchor `hermes-agent.service`.
