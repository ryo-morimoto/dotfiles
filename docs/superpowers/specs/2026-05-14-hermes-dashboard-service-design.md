# Hermes Dashboard Service Design

## Context

Hermes Agent is already integrated on `ryobox` through the upstream `NousResearch/hermes-agent` NixOS module using
container mode with the Podman backend. The gateway service works through the upstream module, but the Web UI dashboard
does not start from `services.hermes-agent.environment.HERMES_DASHBOARD`.

The root cause is an upstream behavior gap:

- Docker image startup uses `docker/entrypoint.sh`, where `HERMES_DASHBOARD=1` starts `hermes dashboard` as a
  side-process.
- NixOS container mode generates and uses its own `containerEntrypoint` in `nix/nixosModules.nix`.
- The NixOS module writes `services.hermes-agent.environment` to `/var/lib/hermes/.hermes/.env`; it does not feed those
  values to systemd `Environment=` and does not implement the Docker entrypoint's dashboard side-process logic.

Upstream issue/PR search found Docker dashboard auto-start work, but no exact NixOS container-mode issue for this gap.
Related upstream references:

- PR #19540: Docker entrypoint dashboard side-process via `HERMES_DASHBOARD=1`.
- PR #16347: earlier Docker dashboard auto-start attempt.
- Issue #9383: NixOS managed-mode dashboard permission problems, related but not this auto-start gap.
- Issue #23184 / PR #23198: NixOS container mode executable lookup bug for Kanban worker spawn, related to container
  mode but not dashboard startup.

## Goal

Run the Hermes Web UI dashboard automatically on `ryobox` as part of the declarative NixOS configuration, without
exposing it to the ordinary LAN.

## Non-Goals

- Do not patch the upstream Hermes flake or NixOS module in this dotfiles change.
- Do not switch Hermes away from the upstream container-mode gateway service.
- Do not add passwordless sudo for host `podman`.
- Do not make the dashboard reachable from non-Tailscale LAN interfaces.
- Do not include unrelated staged documentation changes in the Hermes dashboard commit.

## Constraints

- Keep the implementation in `hosts/ryobox/default.nix`.
- Continue using the existing rootful Podman container created by `hermes-agent.service`.
- Start the dashboard inside the existing `hermes-agent` container, so it shares gateway state, package paths, and
  runtime environment.
- Keep firewall exposure scoped to `tailscale0`.
- Treat `y` as "問題ない / 進めてよい" and `n` as "問題あり / 修正したい" during this design review.

## Chosen Approach

Add a separate `hermes-agent-dashboard.service` systemd unit in `hosts/ryobox/default.nix`.

The service will not create a new container. It will execute the dashboard inside the existing `hermes-agent` container:

```bash
podman exec --user hermes hermes-agent /data/current-package/bin/hermes dashboard \
  --host 0.0.0.0 \
  --port 9119 \
  --no-open \
  --insecure \
  --tui \
  --skip-build
```

The service should be bound to the gateway service:

- `Requires=hermes-agent.service`
- `BindsTo=hermes-agent.service`
- `After=hermes-agent.service`

This means the dashboard starts only when the gateway container exists, stops with the gateway service, and can restart
independently if the dashboard process exits.

Use `Restart=always` with a short restart delay so dashboard crashes recover without restarting the gateway.

The service can run as root on the host because it needs access to the rootful Podman container namespace. It should not
use host-side passwordless sudo. Inside the container, `podman exec --user hermes` keeps dashboard-created files owned
by the same user as the gateway process.

## Network Exposure

The dashboard listens on `0.0.0.0:9119` inside the host-networked container. This is required because the access path is
through the host network namespace and Tailnet address, not through an SSH tunnel.

The host firewall remains the security boundary:

- Do not add `9119` to global `networking.firewall.allowedTCPPorts`.
- Add `9119` only to `networking.firewall.interfaces.tailscale0.allowedTCPPorts`.

Expected result: Tailnet devices can reach `http://ryobox:9119` or `http://<tailscale-ip>:9119`; ordinary same-LAN
clients cannot reach the dashboard through the non-Tailscale interface.

## Configuration Cleanup

Remove the staged `services.hermes-agent.environment.HERMES_DASHBOARD_*` settings from the Hermes gateway block.

Those variables are misleading in NixOS container mode because the upstream module writes them to
`/var/lib/hermes/.hermes/.env`, but the generated container entrypoint does not use them to start a dashboard.

The dashboard's host, port, TUI mode, and public-bind opt-in should live in the dashboard service command instead.

## Alternatives Considered

### Host-Side Dashboard Service

Run `hermes dashboard` directly on the host as another systemd service. This was rejected because host CLI execution in
the current rootful Podman container setup tries to route into the container and requires non-interactive passwordless
`sudo podman`, which is intentionally not enabled.

### Patch Or Overlay The Upstream NixOS Module

Patch the upstream `containerEntrypoint` to copy Docker's `HERMES_DASHBOARD` side-process behavior. This is the right
shape for an upstream PR, but it adds local patch maintenance to dotfiles. The dotfiles fix should stay small and avoid
forking upstream module behavior.

### Tailscale Serve

Keep Hermes bound to localhost and publish it through `tailscale serve`. This avoids a direct `0.0.0.0` bind, but Hermes
dashboard validates the `Host` header for localhost binds. Tailscale Serve may present a Tailnet hostname, which can be
rejected by Hermes's DNS-rebinding protection. Firewall-scoped Tailnet exposure is simpler for this deployment.

## Error Handling

The dashboard service runs the dashboard process in the foreground through `podman exec`.

- If the dashboard exits, systemd restarts `hermes-agent-dashboard.service`.
- If the gateway container is absent or stopped, the dashboard service fails and is retried by systemd after the restart
  delay.
- If `--skip-build` fails because the packaged dashboard dist is missing, remove `--skip-build` and let Hermes perform
  its normal dashboard build path. This is a fallback, not the default, because service startup should avoid unnecessary
  build work.

## Verification Criteria

- WHEN `nixfmt hosts/ryobox/default.nix` is run THEN formatting succeeds.
- WHEN `nix eval` inspects `systemd.services.hermes-agent-dashboard.serviceConfig.ExecStart` THEN the command uses
  `podman exec --user hermes hermes-agent /data/current-package/bin/hermes dashboard`.
- WHEN `nix eval` inspects firewall config THEN global `allowedTCPPorts` does not contain `9119`.
- WHEN `nix eval` inspects `networking.firewall.interfaces.tailscale0.allowedTCPPorts` THEN it contains `9119`.
- WHEN `nix flake check` is run THEN flake evaluation succeeds.
- WHEN `sudo nixos-rebuild switch --flake .` has been run THEN `systemctl status hermes-agent-dashboard.service` is
  `active (running)`.
- WHEN `ss -ltnp` is run after the switch THEN `0.0.0.0:9119` is listening.
- WHEN `curl http://127.0.0.1:9119/` is run after the switch THEN the dashboard returns an HTTP response.

## Commit Scope

The implementation commit should include only the Hermes dashboard service changes, expected to be
`hosts/ryobox/default.nix`. It should not include the already staged
`docs/plans/2026-05-12-001-docs-project-management-design-plan.md` unless that separate documentation change is
intentionally committed on its own.
