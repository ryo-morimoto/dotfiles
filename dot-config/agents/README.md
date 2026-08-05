# Agent Runtime Config

This directory documents mutable AI tool operation.

Stable Claude Code and Codex settings are tracked separately from tool-owned
runtime state, and deployed by chezmoi (source: `dot-config/chezmoi/`):

- `dot-config/chezmoi/private_dot_claude/private_settings.json` is the tracked
  source copied to the writable `~/.claude/settings.json` by `chezmoi apply`.
- `dot-config/chezmoi/.chezmoitemplates/codex/config.toml` is the tracked stable
  base merged into the writable `~/.codex/config.toml` by a chezmoi modify
  template.
- Codex project trust, generated app IDs, hook state, notices, and marketplace
  state remain only in the live file.
- tool-installed skills, plugins, hooks, and MCP entries

Claude Code may rewrite its live settings. Review and pull those changes with
the standard chezmoi flow:

```bash
chezmoi diff ~/.claude/settings.json      # review drift
chezmoi re-add ~/.claude/settings.json    # pull into the source
chezmoi apply --force                     # push tracked source over live
```

Global instruction and APM source config files are chezmoi-managed copies:

- `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` are rendered from the shared
  `dot-config/chezmoi/.chezmoitemplates/AGENTS.md`.
- `~/.apm/apm.yml`, `~/.apm/config.json`, and `~/.apm/marketplaces.json` come
  from `dot-config/chezmoi/dot_apm/`; when apm rewrites them, review and
  `chezmoi re-add`.

The tracked `dot-config/agents/apm/apm.lock.yaml` stays adjacent to the APM
reference tree as a reproducibility input. The live `~/.apm/apm.lock.yaml`,
package cache, deployed skills, generated agents, and MCP runtime outputs remain
tool-owned generated state; let `apm install --global` regenerate them.

Nix may enable stable agent tool packages and run config lifecycle scripts, but
does not generate the JSON or TOML content. Tool behavior, shared prompts, and
reviewed examples belong here.

Use this directory for shared instructions, reviewed examples, notes, and migration snippets.
The live Codex file remains the source of truth only for tool-owned dynamic
state. The tracked files under `dot-config/chezmoi/` are the source of truth
for stable settings.

Promotion rule: keep disposable tools and settings outside Nix. Promote a tool
to nixpkgs or a maintained community package source only after it has been useful
for at least one month and rebuild-time management is worth the maintenance cost.
