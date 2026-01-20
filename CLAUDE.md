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
nixfmt-tree       # Format Nix files
statix check .    # Lint for anti-patterns
deadnix .         # Find unused code
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
