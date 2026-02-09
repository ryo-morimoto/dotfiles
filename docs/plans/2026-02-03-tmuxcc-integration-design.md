# tmuxcc Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add tmuxcc as a tmux popup overlay for managing multiple Claude Code sessions with approval queue.

**Architecture:** tmuxcc is a Rust TUI that polls tmux panes to detect AI agent status. We package it with Nix, add a tmux keybinding to launch it as a popup, and provide a config file via mkOutOfStoreSymlink.

**Tech Stack:** Nix (rustPlatform.buildRustPackage), Home Manager, tmux display-popup

---

### Task 1: Create tmuxcc Nix package

**Files:**
- Create: `packages/tmuxcc.nix`

**Step 1: Create the package file**

Reference: `packages/claude-squad.nix` uses `buildGoModule`. tmuxcc is Rust, so use `rustPlatform.buildRustPackage`.

```nix
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "tmuxcc";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "nyanko3141592";
    repo = "tmuxcc";
    rev = "v${version}";
    hash = "";
  };

  useFetchCargoVendor = true;
  cargoHash = "";

  meta = with lib; {
    description = "AI Agent Dashboard for tmux - Monitor Claude Code, OpenCode, Codex CLI, and Gemini CLI";
    homepage = "https://github.com/nyanko3141592/tmuxcc";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "tmuxcc";
  };
}
```

**Step 2: Register in flake.nix overlay**

In `flake.nix`, add to `localOverlay`:

```nix
localOverlay = final: prev: {
  vibe-kanban = final.callPackage ./packages/vibe-kanban.nix { };
  claude-squad = final.callPackage ./packages/claude-squad.nix { };
  tmuxcc = final.callPackage ./packages/tmuxcc.nix { };
};
```

**Step 3: Build to get hashes**

Run: `nix build .#nixosConfigurations.ryobox.config.system.build.toplevel 2>&1`

The build will fail twice with hash mismatches. Copy the correct `sha256-...` hashes into the `hash` and `cargoHash` fields.

**Step 4: Verify build succeeds**

Run: `nix build .#nixosConfigurations.ryobox.config.system.build.toplevel`
Expected: Build completes without error.

**Step 5: Commit**

```bash
git add packages/tmuxcc.nix flake.nix
git commit -m "feat: add tmuxcc Nix package"
```

---

### Task 2: Add tmuxcc to home packages and tmux popup keybinding

**Files:**
- Modify: `home/default.nix`

**Step 1: Add tmuxcc to home.packages**

In `home/default.nix`, add `tmuxcc` to the packages list (after `claude-squad` on line 138):

```nix
      claude-squad
      tmuxcc
    ];
```

**Step 2: Add tmux popup keybinding**

In the `tmux.extraConfig` section, add after the reload config binding (line 461):

```
        # tmuxcc dashboard popup (Ctrl+q d)
        bind d display-popup -E -w 80% -h 80% tmuxcc
```

**Step 3: Verify syntax**

Run: `nix flake check`
Expected: No errors.

**Step 4: Commit**

```bash
git add home/default.nix
git commit -m "feat: add tmuxcc package and tmux popup keybind"
```

---

### Task 3: Add tmuxcc config file

**Files:**
- Create: `config/tmuxcc/config.toml`
- Modify: `home/default.nix` (xdg.configFile symlink)

**Step 1: Create config directory and file**

```toml
poll_interval_ms = 500
capture_lines = 100
```

**Step 2: Add mkOutOfStoreSymlink to home/default.nix**

In the `xdg.configFile` section (after line 530):

```nix
    "tmuxcc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/tmuxcc";
```

**Step 3: Verify syntax**

Run: `nix flake check`
Expected: No errors.

**Step 4: Commit**

```bash
git add config/tmuxcc/config.toml home/default.nix
git commit -m "feat: add tmuxcc config with symlink"
```

---

### Task 4: Apply and verify

**Step 1: Apply configuration**

Run: `sudo nixos-rebuild switch --flake .#ryobox`
Expected: Build and activation succeed.

**Step 2: Verify tmuxcc binary**

Run: `which tmuxcc`
Expected: Path to tmuxcc binary.

**Step 3: Verify tmux keybinding**

In tmux, press `Ctrl+q d`.
Expected: tmuxcc TUI opens in a popup overlay.

**Step 4: Verify config**

Run: `ls -la ~/.config/tmuxcc/config.toml`
Expected: Symlink pointing to dotfiles repo.

**Step 5: Test with Claude Code session**

Open a Claude Code session in another pane, then `Ctrl+q d` to open tmuxcc.
Expected: tmuxcc detects and displays the Claude Code session with status.
