# lsmcp Workflow

## TypeScript

```text
get_project_overview()
search_symbols("main")
get_symbol_details("main")
diagnostics()
references("REPLACE_WITH_SYMBOL")
```

## MoonBit

```text
get_project_overview()
search_symbols("REPLACE_WITH_FUNCTION")
get_symbol_details("REPLACE_WITH_FUNCTION")
diagnostics()
```

## Use With codedb

- Ask `codedb` for broad dependency and task context.
- Ask `lsmcp` for exact symbols, definitions, diagnostics, rename, and references.

