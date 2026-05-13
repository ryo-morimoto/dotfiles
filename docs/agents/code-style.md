# Code Style

この repository は Nix を主言語とする。既存 module の責務と粒度を優先する。

## Formatting

- `.nix` ファイルは必ず `nixfmt` を使う。
- indentation は 2 spaces。
- line length は nixfmt の既定に従う。
- imports は attribute set 内で alphabetically に整理する。
- conditionals は `lib.mkIf`、options は `lib.mkEnableOption` / `lib.mkOption` を使う。

## Imports And Dependencies

```nix
{ lib, config, pkgs, ... }:

{
  lib,
  fetchFromGitHub,
  buildGoModule,
  myLocalPackage,
}:
```

## Naming

- Variables: `snake_case` or local convention.
- Functions: `camelCase`.
- Options: `camelCase`, for example `programs.zsh.enable`.
- Packages: `kebab-case`.
- Package files: `packages/<name>.nix`.
- Module files: `default.nix`.

## Types And Assertions

- Packages define `meta` with `description`, `license`, and `platforms`.
- Home Manager options use the type system, such as `types.bool`, `types.str`, and `types.path`.
- Invalid parameter combinations should use assertions or warnings instead of ad hoc runtime behavior.

```nix
lib.mkIf (cfg.enable && cfg.disable) (lib.warn "矛盾した設定" null)
```

## Error Handling

- Use `lib.warn` or `lib.trivial.warn` for non-fatal issues.
- Avoid `throw` in pure configurations when assertions can express the constraint.
- Prefer `lib.optional` and `lib.optionalString` for conditional list/string fragments.

## Organization

- One package per file under `packages/`.
- Host-specific config belongs in `hosts/<hostname>/`.
- User environment config belongs in `home/`.
- Keep `flake.nix` minimal and delegate details to modules.
- Secret management goes through agenix under `secrets/`.

## Git Commit Style

- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `style:`.
- Prefer small focused commits.
- Use `chore: update flake.lock` for dependency lockfile updates.
- Example: `feat(niri): add workspace keybindings`.
