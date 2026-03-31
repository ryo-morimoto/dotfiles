---
name: knowledge-management
description: Manage knowledge in the Obsidian vault at ~/obsidian. Use when asked to log learnings, search past knowledge, create notes, review drafts, or manage the vault. Also activates on "ナレッジ", "メモ", "vault", "知見", "TIL", "振り返り", "daily", "デイリー". Handles both manual capture and automated session logging.
compatibility: Requires Obsidian CLI (v1.12+) and ~/obsidian vault
---

# Knowledge Management

Manage the Obsidian vault at `~/obsidian/`.

## Vault Structure

```
~/obsidian/
├── AGENTS.md      # Agent rules (read this first)
├── Daily/         # Daily notes (YYYY-MM-DD.md)
├── Templates/     # Note templates
├── Attachments/   # Images, PDFs
└── *.md           # All content notes — flat in root
```

No nested folders. Classification is done via frontmatter, not folder hierarchy.

## Frontmatter Schema

Every note MUST have:

```yaml
---
date: "YYYY-MM-DD"
categories: [knowledge]     # knowledge | project | reading | idea | daily
tags: [kebab-case-tags]     # technical tags
source: auto | manual       # who created it
status: draft | published   # draft = unreviewed by human
---
```

## 記録すべき知見

ドキュメントだけでは到達しにくい知見のみ記録する。

| 種類 | タグ |
|---|---|
| システムの非自明な挙動・undocumented な動作 | `gotcha`, `undocumented` |
| ライブラリのハマりどころ（エッジケース、バージョン非互換、暗黙の前提） | `pitfall`, `library-specific` |
| deep dive で得た内部実装の理解・根本原因 | `deep-dive`, `root-cause` |
| best practice の curation（状況・適用方法・選択理由の三点セット） | `best-practice`, `curation` |
| 設計判断の理由（選択理由＋棄却理由） | `decision`, `trade-off` |

記録は `WHEN [条件] THEN [起きること] BECAUSE [原因]` の形式で具体的に書く。

## 検索トリガー

以下の状況では実装前に vault を検索する:

- 同種のエラー・問題に遭遇した
- ライブラリの設定・統合に取り組む
- 設計判断を求められた
- best practice を適用しようとしている
- 「前にやったはず」という感覚がある

## Agent Write Rules

1. **Daily/** — Free to append. `## Session {HH:MM}` heading で追記。
2. **Root notes** — `source: auto, status: draft` で作成。human が publish する。
3. 既存ノートの `status`, `categories`, `source` は変更しない。
4. 既存ノートの削除・上書きはしない。
5. `[[wikilinks]]` で相互参照する。

## Workflows

### Capture

1. category 判定 → `{descriptive-slug}.md` を vault root に作成
2. user 起点なら `source: manual, status: published`、agent 起点なら `source: auto, status: draft`
3. 関連タグ・`[[wikilinks]]` 付与 → Daily note に参照追記

### Search

1. `~/obsidian/` を keyword + frontmatter tags で検索
2. 上位 5 件を読み、`[[note-name]]` で引用して回答

### Review Drafts

1. `status: draft` を検索 → 一覧提示
2. user が publish / edit / delete を判断

### Daily Log (自動)

Stop hook (`scripts/session-sync.mjs`) がセッションサマリを `Daily/YYYY-MM-DD.md` に追記。

See [vault rules](references/vault-rules.md) for detailed specs.
