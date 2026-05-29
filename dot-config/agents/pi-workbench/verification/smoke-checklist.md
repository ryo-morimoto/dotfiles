# Smoke Checklist

Run these in disposable profiles first. Do not mutate live agent config during first validation.

## 1. Environment

- [ ] `node --version` is `>=24.15.0` for selected Pi packages.
- [ ] `pi --version` is recorded.
- [ ] Disposable Pi config/profile path is recorded.
- [ ] Redaction package/policy is enabled before memory or telemetry checks.

## 2. ACP

- [ ] Start `acp-adapter --adapter pi --pi-provider openai-codex --pi-model REPLACE_WITH_MODEL`.
- [ ] Start a Zed ACP session.
- [ ] Send a prompt and confirm streaming response.
- [ ] List and load a Pi session.
- [ ] Trigger edit/write/bash permission prompts and confirm Zed shows them.

## 3. Pi Packages

- [ ] Install `@spences10/pi-mcp`.
- [ ] Install `@spences10/pi-lsp`.
- [ ] Install `@spences10/pi-context`.
- [ ] Install `@spences10/pi-recall`.
- [ ] Install `@spences10/pi-telemetry`.
- [ ] Install `@spences10/pi-redact`.
- [ ] Install `@spences10/pi-skills`.
- [ ] Confirm each package registers expected commands/tools.

## 4. Permissions

- [ ] Safe read/search command is allowed.
- [ ] Test command is allowed.
- [ ] Edit/write action asks.
- [ ] Destructive git operation asks or denies according to policy.
- [ ] Secret read is denied.
- [ ] `git push` is denied.
- [ ] MCP server/tool restriction works.
- [ ] Subagent permission request forwards to parent.

## 5. Code Context

- [ ] `codedb_context` returns task-shaped context.
- [ ] `codedb_deps` returns changed-file neighborhood.
- [ ] Sensitive-file blocking is verified.
- [ ] `lsmcp` project overview works.
- [ ] `lsmcp` symbol search/details work.
- [ ] `lsmcp` diagnostics and references work.

## 6. Memory

- [ ] `mem_current_project` returns the expected project.
- [ ] `mem_context` returns scoped context.
- [ ] `mem_save_prompt` records a prompt.
- [ ] `mem_capture_passive` creates a candidate/passive entry, not an unchecked permanent global memory.
- [ ] Session summary/end tools work.
- [ ] Redaction is visible in stored records.
- [ ] Magic Context is tested separately before enabling with Engram.

## 7. Session Search

- [ ] Codex sessions search by keyword.
- [ ] Claude sessions search by keyword.
- [ ] Recent sessions list by project.
- [ ] Paginated session retrieval works.
- [ ] Pi session storage path is inspected.
- [ ] Pi adapter/importer decision is recorded.

## 8. Code Mode

- [ ] `pctx` can call a read-only MCP tool.
- [ ] Generated code cannot read raw filesystem.
- [ ] Generated code cannot read env secrets.
- [ ] Generated code cannot use arbitrary network access.
- [ ] `mcpc` can call one configured MCP tool with JSON output.

## 9. Distribution And Models

- [ ] APM manifest dry-run works.
- [ ] APM audit works or the missing audit command is recorded.
- [ ] Small local/open model summarizes a short memory fixture.
- [ ] Review local/open model reviews a small read-only diff.
- [ ] Patch authoring remains on the reliable model.

## Receipt Format

For each completed smoke, record:

```text
Date:
Candidate:
Version / commit:
Command:
Config path:
Observed result:
Pass / fail:
Follow-up:
```

