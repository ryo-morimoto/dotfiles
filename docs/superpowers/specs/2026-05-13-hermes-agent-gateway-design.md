# Hermes Agent Gateway Design

## Context

Add Nous Research's Hermes Agent to the `ryobox` NixOS configuration as a long-running gateway service.

Hermes is not an APM-distributed Claude/Codex agent. Its upstream repository exposes a standalone CLI, a gateway
process, a Nix flake, and a NixOS module. The upstream NixOS module supports native and OCI container modes, with
container backends limited to `docker` and `podman`.

Relevant sources:

- Hermes repository: <https://github.com/NousResearch/hermes-agent>
- Hermes flake: <https://raw.githubusercontent.com/NousResearch/hermes-agent/main/flake.nix>
- Hermes NixOS module: <https://raw.githubusercontent.com/NousResearch/hermes-agent/main/nix/nixosModules.nix>
- Hermes provider docs: <https://raw.githubusercontent.com/NousResearch/hermes-agent/main/website/docs/integrations/providers.md>
- Hermes configuration docs:
  <https://raw.githubusercontent.com/NousResearch/hermes-agent/main/website/docs/user-guide/configuration.md>
- NixOS Podman reference: <https://nixos.wiki/wiki/Podman>

## Goal

Run `hermes gateway` as a declarative NixOS service on `ryobox`, using container mode and the OpenAI Codex OAuth
provider.

## Non-Goals

- Do not manage an OpenAI API key through agenix for this change.
- Do not add Hermes skills or plugins.
- Do not configure Telegram, Discord, Slack, WhatsApp, Signal, Email, or other messaging credentials.
- Do not remove Docker from the host as part of this change.
- Do not replace existing Claude Code, Codex, APM, or MCP configuration.

## Constraints

- Preserve the repository's declarative NixOS and Home Manager configuration style.
- Use upstream Hermes NixOS module behavior instead of duplicating service, state, and container setup manually.
- OAuth credentials must not be committed to the repo. Hermes should persist them in its runtime state.
- `~/.hermes` should be managed by the upstream module's `hostUsers` bridge, with the actual state under
  `/var/lib/hermes/.hermes`.
- Podman must be enabled explicitly because the Hermes module only auto-enables Docker for the Docker backend.

## Chosen Approach

Use the upstream Hermes flake and NixOS module:

1. Add `NousResearch/hermes-agent` as a flake input.
2. Import `hermes-agent.nixosModules.default` into the `ryobox` NixOS module list.
3. Enable Podman as the container runtime:
   - `virtualisation.containers.enable = true`
   - `virtualisation.podman.enable = true`
   - `virtualisation.podman.defaultNetwork.settings.dns_enabled = true`
4. Enable Hermes gateway:
   - `services.hermes-agent.enable = true`
   - `services.hermes-agent.container.enable = true`
   - `services.hermes-agent.container.backend = "podman"`
   - `services.hermes-agent.container.hostUsers = [ "ryo-morimoto" ]`
   - `services.hermes-agent.addToSystemPackages = true`
5. Configure the default Hermes provider as OpenAI Codex OAuth:
   - `services.hermes-agent.settings.model.provider = "openai-codex"`
   - Leave the concrete model/default selection to `hermes model` unless implementation confirms a stable upstream
     model ID that should be pinned declaratively.

## Alternatives Considered

### Docker Backend

Docker is already enabled on `ryobox`, so it would be the smallest diff. It was not chosen because Podman is supported
by the upstream Hermes module, is a normal NixOS container backend, and avoids leaning further into Docker socket and
`docker` group access for this new service.

### Custom Systemd Service

This would offer more direct control, but it would duplicate upstream module behavior for state directories,
configuration merging, `.container-mode` metadata, and container lifecycle handling. It is rejected unless the upstream
module proves unusable.

### Installer-Managed Hermes

Running the upstream install script outside Nix would be fast, but it would create unmanaged installation state under
the user's home directory and conflict with this repository's declarative configuration policy.

## State And Authentication

OpenAI Codex OAuth is performed interactively with Hermes, not declared as a secret file. After deployment, the user
will run `hermes model` and choose the OpenAI Codex OAuth path. Hermes stores the resulting credential in
`/var/lib/hermes/.hermes/auth.json`. The service may exist before OAuth is completed, but it is not expected to be
fully usable until `hermes model` has stored the OAuth credential and model selection.

The NixOS module's `container.hostUsers` bridge should make the interactive `hermes` CLI use the same state as the
gateway service by linking the user's `~/.hermes` to `/var/lib/hermes/.hermes`.

## Verification Criteria

- WHEN `nix flake check` is run THEN flake evaluation succeeds.
- WHEN `nix eval .#nixosConfigurations.ryobox.config.services.hermes-agent.container.backend` is run THEN it returns
  `"podman"`.
- WHEN `nix eval .#nixosConfigurations.ryobox.config.virtualisation.podman.enable` is run THEN it returns `true`.
- WHEN NixOS is switched and `hermes model` completes the OpenAI Codex OAuth flow THEN
  `/var/lib/hermes/.hermes/auth.json` contains the persisted credential and `hermes gateway` uses the same state.

## Implementation Notes

- The service configuration belongs in `hosts/ryobox/default.nix` because this is host-level NixOS service state.
- The flake input and output wiring belongs in `flake.nix`.
- No changes are expected in `home/agents/` because Hermes is not part of the existing APM-managed Claude/Codex agent
  package set.
- If Podman networking issues appear, verify `virtualisation.containers.enable` and Podman DNS settings before changing
  Hermes service settings.
