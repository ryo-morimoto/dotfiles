# codedb Query Presets

Use these as textual review surfaces before considering a graph viewer.

## change_neighborhood

```text
codedb_deps("REPLACE_WITH_CHANGED_FILE")
```

Expected use: find directly related files and likely test targets.

## risk_surface

```text
codedb_context("What callbacks, hooks, entrypoints, or config files can affect REPLACE_WITH_CHANGED_FILE?")
```

Expected use: identify hidden runtime paths before changing code.

## review_path

```text
codedb_context("Review this change plan for missing tests and risky dependencies: REPLACE_WITH_PLAN")
```

Expected use: guide a reviewer agent without creating a custom UI.

