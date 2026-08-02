# Agent Runtime Config

This directory documents mutable AI tool operation.

Stable Claude Code and Codex settings are tracked separately from tool-owned
runtime state:

- `dot-config/config/claude/settings.json` is the tracked source copied to the
  writable `~/.claude/settings.json` during Home Manager activation.
- `dot-config/config/codex/config.toml` is the tracked stable base merged into
  the writable `~/.codex/config.toml` during activation.
- Codex project trust, generated app IDs, hook state, notices, and marketplace
  state remain only in the live file.
- tool-installed skills, plugins, hooks, and MCP entries

Claude Code may rewrite its live settings. Review and pull those changes before
the next rebuild:

```bash
claude-config-check
claude-config-pull
```

Use `claude-config-push` to discard live drift in favor of the tracked source.
Push and Codex merge operations keep the previous live file at the adjacent
`*.pre-dotfiles` path. Pull refuses private-looking repository paths and files
rejected by gitleaks.

Global instruction and APM source config files are managed by Home Manager symlinks:

- `~/.codex/AGENTS.md` -> `dot-config/agents/AGENTS.md`
- `~/.claude/CLAUDE.md` -> `dot-config/agents/AGENTS.md`
- `~/.apm/apm.yml` -> `dot-config/agents/apm/apm.yml`
- `~/.apm/config.json` -> `dot-config/agents/apm/config.json`
- `~/.apm/marketplaces.json` -> `dot-config/agents/apm/marketplaces.json`

Keep `dot-config/agents/apm/apm.yml` and its adjacent `apm.lock.yaml` together as
the tracked reproducibility inputs. The live `~/.apm/apm.lock.yaml`, package
cache, deployed skills, generated agents, and MCP runtime outputs remain
tool-owned generated state; let `apm install --global` regenerate them.

Nix may enable stable agent tool packages and run config lifecycle scripts, but
does not generate the JSON or TOML content. Tool behavior, shared prompts, and
reviewed examples belong here.

Use this directory for shared instructions, reviewed examples, notes, and migration snippets.
The live Codex file remains the source of truth only for tool-owned dynamic
state. The tracked files under `dot-config/config/` are the source of truth for
stable settings.

Promotion rule: keep disposable tools and settings outside Nix. Promote a tool
to nixpkgs or a maintained community package source only after it has been useful
for at least one month and rebuild-time management is worth the maintenance cost.
