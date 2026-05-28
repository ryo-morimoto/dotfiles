# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS dotfiles repository using **Nix Flakes** with **Home Manager** (integrated as NixOS module) for declarative system and user configuration.

## Commands

```bash
# Apply both system and user configuration (Home Manager is integrated)
sudo nixos-rebuild switch --flake ./nix-config#ryobox

# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update ./nix-config

# Check flake syntax without building
nix flake check ./nix-config

# Nix code quality (installed tools)
nixfmt            # Format Nix files
statix check .    # Lint for anti-patterns
deadnix .         # Find unused code

# Git hooks (run once after clone)
prek install -t pre-commit -t pre-push
```

## Architecture

### Nix Structure

- **`nix-config/flake.nix`** - Entry point. Defines inputs (nixpkgs, home-manager, etc.) and integrates Home Manager as NixOS module
- **`nix-config/home/default.nix`** - User environment: packages, programs (git, zsh, starship, fzf, etc.), shell aliases, XDG config symlinks
- **`nix-config/hosts/ryobox/default.nix`** - System config: bootloader, networking, locale (ja_JP), Niri compositor, audio (PipeWire), fonts
- **`nix-config/hosts/ryobox/hardware-configuration.nix`** - Auto-generated hardware config (do not edit manually)

### Config Files

Application configs in `dot-config/config/` are symlinked via `mkOutOfStoreSymlink` for instant changes without rebuild:

- `dot-config/config/ghostty/` - Ghostty terminal
- `dot-config/config/niri/` - Niri compositor (primary WM)
- `dot-config/config/lazygit/` - Lazygit

AI tool runtime config lives outside Nix management. Use `dot-config/agents/` for notes and reviewed examples; live `~/.codex`, `~/.claude`, and `~/.apm` files are owned by the tools.

### Where to Add Packages

- **System packages**: `nix-config/hosts/ryobox/default.nix` → `environment.systemPackages`
- **User packages**: `nix-config/home/default.nix` → `home.packages`
- **Programs with config**: Use Home Manager modules in `nix-config/home/default.nix` for stable config only

### Shell Aliases (defined in nix-config/home/default.nix)

Git: `g`, `gs`, `gd`, `ga`, `gc`, `gp`, `gl`
Modern CLI: `ls`→eza, `cat`→bat, `grep`→rg, `find`→fd

### Nix Editing Guidelines

- Nix files have deeply nested, repetitive structure. Always use large context blocks for Edit `old_string`.
- When adding packages to a list, include the list header AND at least 2 existing items as context for uniqueness.
- After editing any `.nix` file, validate with `nix flake check` (flake files) or `nixfmt` (formatting).
- Common Nix edit failures: missing semicolons, unbalanced braces, incorrect attribute path nesting.

## Ongoing Interests

- **Desktop environment improvement**: Always exploring a more usable desktop setup. Currently using Niri + waybar, but considering integrated desktop shells like [DankMaterialShell (DMS)](https://github.com/AvengeMedia/DankMaterialShell). DMS provides NixOS Flake / Home Manager modules with Niri integration options.

### Playwright Setup

This system uses **Chromium-only via Nix `playwright-driver`**. Environment variables are managed by Home Manager (`home.sessionVariables`):

- `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` - Prevents npm from downloading browsers
- `PLAYWRIGHT_BROWSERS_PATH` - Points to `pkgs.playwright-driver.browsers.override { withFirefox = false; withWebkit = false; }`
- `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true` - Avoids distro validation noise on NixOS
- `CHROME_PATH` - Compatibility fallback to system Chromium

**Usage in projects (recommended):**

```bash
npm install -D @playwright/test
```

Avoid `npx playwright install` and `npx playwright install-deps` on this system. Browsers are provided by Nix.

Keep Playwright version in `package.json` aligned with nixpkgs `playwright-driver` when possible.

```typescript
import { chromium } from 'playwright-core';

const browser = await chromium.launch({
  // Usually no executablePath is needed when PLAYWRIGHT_BROWSERS_PATH is set.
  executablePath: process.env.CHROME_PATH,
});
```
