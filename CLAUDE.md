# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS dotfiles repository using **Nix Flakes** with **Home Manager** (integrated as NixOS module) for declarative system and user configuration.

## Commands

```bash
# Apply both system and user configuration (Home Manager is integrated)
sudo nixos-rebuild switch --flake .#ryobox

# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update

# Check flake syntax without building
nix flake check

# Nix code quality (installed tools)
nixfmt            # Format Nix files
statix check .    # Lint for anti-patterns
deadnix .         # Find unused code

# Git setup (run once after clone)
git config core.hooksPath hooks
git config filter.waypaper.clean './scripts/git-filters/waypaper-clean.sh'
git config filter.waypaper.smudge 'cat'
```

## Architecture

### Nix Structure

- **`flake.nix`** - Entry point. Defines inputs (nixpkgs, home-manager, claude-code-overlay) and integrates Home Manager as NixOS module
- **`home/default.nix`** - User environment: packages, programs (git, zsh, starship, fzf, etc.), shell aliases, XDG config symlinks
- **`hosts/ryobox/default.nix`** - System config: bootloader, networking, locale (ja_JP), Niri compositor, audio (PipeWire), fonts
- **`hosts/ryobox/hardware-configuration.nix`** - Auto-generated hardware config (do not edit manually)

### Config Files

Application configs in `config/` are symlinked via `mkOutOfStoreSymlink` for instant changes without rebuild:

- `config/ghostty/` - Ghostty terminal
- `config/niri/` - Niri compositor (primary WM)
- `config/hypr/` - Hyprland (alternative WM)

### Where to Add Packages

- **System packages**: `hosts/ryobox/default.nix` → `environment.systemPackages`
- **User packages**: `home/default.nix` → `home.packages`
- **Programs with config**: Use Home Manager modules in `home/default.nix` (e.g., `programs.git`, `programs.zsh`)

### Shell Aliases (defined in home/default.nix)

Git: `g`, `gs`, `gd`, `ga`, `gc`, `gp`, `gl`
Modern CLI: `ls`→eza, `cat`→bat, `grep`→rg, `find`→fd

### Playwright Setup

This system uses **Option A: External Chromium** for Playwright. Environment variables are set in zsh:

- `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` - Prevents npm from downloading browsers
- `CHROME_PATH` - Points to system Chromium

**Usage in projects:**

```bash
# Use playwright-core instead of playwright
npm install playwright-core
```

```typescript
import { chromium } from 'playwright-core';

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/run/current-system/sw/bin/chromium',
});
```
