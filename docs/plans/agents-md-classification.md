# home/agents/_AGENTS.md の MECE 分類と再設計判断

作成日: 2026-05-12

## 対象範囲

このメモは `home/agents/_AGENTS.md` の内容を MECE に分類し、AGENTS.md / CLAUDE.md の最新ベストプラクティスを調査した上で、各指示を「残す」「一般的な形式へ書き直す」「別の仕組みに移す」「消す」のどれにするか判断する。

確認したローカルソース:

- `home/agents/_AGENTS.md`: Claude Code と Codex の両方に読み込ませている共有の個人向け agent 指示。
- `home/agents/codex.nix`: `_AGENTS.md` を `programs.codex.context` に注入している。
- `home/agents/claude-code.nix`: `_AGENTS.md` を `programs.claude-code.context` に注入している。
- `AGENTS.md`: dotfiles repo 固有の運用ガイド。
- `CLAUDE.md`: Claude Code 向けの repo 固有ガイド。現在は `AGENTS.md` とは独立している。

## 外部調査の要約

一次ソースと高シグナルな参考資料:

| ソース | 要点 | `_AGENTS.md` への示唆 |
| --- | --- | --- |
| OpenAI Codex AGENTS.md docs: https://developers.openai.com/codex/guides/agents-md | Codex は global / project の `AGENTS.md` と `AGENTS.override.md` を読み、root から leaf へ結合する。近いファイルほど後ろに入るため優先される。結合サイズは既定で 32 KiB 上限。 | global 指示は短く保つ。repo 固有情報は repo `AGENTS.md` や nested file に置く。常時ロードの巨大マニュアルにしない。 |
| AGENTS.md official site: https://agents.md | AGENTS.md は agent 用 README。よく入る内容は project overview、build/test command、code style、testing、security。必須 field はない。最も近い AGENTS.md が優先され、明示的な user prompt はさらに優先される。 | 退屈で標準的な Markdown 構成に寄せる。広い行動哲学より、project fact と command を優先する。 |
| Claude Code memory docs: https://code.claude.com/docs/en/memory | Claude Code は `AGENTS.md` ではなく `CLAUDE.md` を読む。repo が `AGENTS.md` を使うなら `CLAUDE.md` から import するか symlink する。CLAUDE.md は毎 session 必要な fact の置き場で、複数 step の手順は skill や path-scoped rule に移すべき。 | global `_AGENTS.md` に詳細 workflow を持たせない。repo の `CLAUDE.md` と `AGENTS.md` は drift を避けるため揃える。 |
| Claude Code best practices: https://code.claude.com/docs/en/best-practices | context window が最重要資源。過剰指定された memory file は重要指示が埋もれる。最も効くのは test、screenshot、期待出力など、agent が自分で検証できる基準を渡すこと。 | 行動を変えない指示は消す。source-first と verification 系の指示は残す。 |
| Claude Code settings docs: https://code.claude.com/docs/en/settings | memory file は instructions/context、settings は permission・environment・tool behavior、skills は invocable prompt、MCP は tool 追加の責務。 | permission policy、tool 配線、deterministic enforcement を AGENTS.md に書かない。settings、hooks、scripts、skills に置く。 |
| Anthropic advanced patterns PDF: https://resources.anthropic.com/hubfs/Claude%20Code%20Advanced%20Patterns_%20Subagents%2C%20MCP%2C%20and%20Scaling%20to%20Real%20Codebases.pdf | 大きい codebase では階層化された instruction file を使う。CLAUDE.md はおおむね 200 行未満。deterministic automation は hooks、外部システム連携は MCP。 | command 強制や繰り返し手順は常時ロード文書から外す。 |
| Amp manual: https://ampcode.com/manual | Amp は cwd / parent / subtree の `AGENTS.md` を読む。top-level は一般的に、subtree は具体的に保つ。`@` reference と globs で progressive disclosure ができる。deterministic / project-local behavior は tools や skills が向く。 | `_AGENTS.md` は compact な routing layer にする。深い運用ルールは skills/docs に逃がす。 |
| Cursor rules docs: https://docs.cursor.com/context/rules-for-ai | 良い rule は focused、actionable、scoped。大きい rule は composable に分割する。AGENTS.md は structured rule の簡易代替。 | global 指示は focused/actionable に保つ。必要なら scoped rule に移す。 |
| Zed rules docs: https://zed.dev/docs/ai/rules | Zed は `.rules`、`AGENTS.md`、`CLAUDE.md` など複数 filename を互換目的で読む。ただし最初に match した rule file が使われる。 | shared text は AGENTS.md 互換の plain Markdown にし、tool-specific syntax を避ける。 |
| Aider conventions docs: https://aider.chat/docs/usage/conventions.html | 小さい convention file は read-only として読み込め、prompt caching と相性がよい。 | 具体的な convention は有用。抽象的な slogan は不要。 |
| HumanLayer "Writing a good CLAUDE.md": https://www.humanlayer.dev/blog/writing-a-good-claude-md | CLAUDE.md は project の why/what/how を示す。短く、普遍的に、progressive disclosure を使う。linter/formatter の代替にしない。 | AGENTS.md は persistent fact と preference に限定し、linter や full process manual にしない。 |
| LangChain domain-specific Claude Code post: https://www.langchain.com/blog/how-to-turn-claude-code-into-a-domain-specific-coding-agent | base instruction と必要時に読める specific docs を組み合わせたとき結果が良かった。 | base guidance は小さくし、詳細は docs/skills への導線にする。 |

## 配置モデル

| 内容 | 置き場所 | 理由 |
| --- | --- | --- |
| cross-project な作業合意 | user/global AGENTS.md または `_AGENTS.md` | どの repo でも毎 session 使うため。 |
| repo 構造、build/test command、Nix convention | root `AGENTS.md` | repo 固有で、version 管理されるべきため。 |
| Claude-only behavior | `CLAUDE.md` または Claude settings/rules | Claude Code は AGENTS.md を直接読まないため。 |
| Codex-only behavior | `~/.codex/config.toml`、Codex AGENTS.md、Codex skills/plugins | Codex 固有 detail を他 agent に漏らさないため。 |
| subtree 固有 rule | nested AGENTS.md / `.claude/rules` / globs 付き referenced docs | top-level を短く保ち、無関係な rule を読ませないため。 |
| 複数 step の workflow | skills / slash commands / workflow docs | 必要時だけ load されるべきため。 |
| format/test の強制 | scripts、hooks、CI、formatter/linter config | 自然言語指示より executable check の方が強いため。 |
| tool permission / secret access | tool settings / managed policy | permission は prompt ではなく config の責務。 |
| 外部 integration | MCP config または skill-bundled MCP | tool list と context を肥大化させないため。 |
| 歴史的経緯・実験ログ | docs/plans、ADR、Obsidian knowledge | 毎 session 必要ではないため。 |

## 詳細 MECE 分類

| ID | 分類 | 現在の内容 | 行 | 現在の役割 | 判断 | 移行先 |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | 意思決定 | 意図が不明なときだけ聞く。 | 6-9 | clarifying question の条件を制御する。 | 残す。短く書き直す。 | `_AGENTS.md` の Decision Policy。 |
| D2 | 意思決定 | 曖昧な質問は意図整理、明確な質問は直接回答。 | 8-9 | 過剰質問を防ぐ。 | 残す。 | `_AGENTS.md`。 |
| D3 | 意思決定 | 非自明な選択では採用案・却下案・trade-off を共有。 | 11-13 | 判断を監査可能にする。 | 残す。「非自明な場合のみ」を強調。 | `_AGENTS.md`。 |
| D4 | 実行境界 | 自明な直接指示は承認なしで実行。 | 15-17 | 不要な承認 loop を防ぐ。 | 残す。 | `_AGENTS.md`。 |
| D5 | 実行境界 | 非自明な設計/API/schema/interface 変更は確認。 | 17-18 | contract と大きな設計判断を守る。 | 残す。`AskUserQuestion` 固有表現は tool-neutral にする。 | `_AGENTS.md`。 |
| D6 | 実行境界 | 質問への回答後は即実行。 | 57-59 | 要約・再確認 loop を防ぐ。 | 残す。D4-D5 に統合。 | `_AGENTS.md`。 |
| H1 | 理解保持 | 非自明な plan/design への未読短承諾を制限。 | 20-30 | user が理解を放棄したまま委任する状態を防ぐ。 | 残す。短縮。 | `_AGENTS.md`。 |
| H2 | 理解保持 | error/code/diff context がない risky request では止める。 | 24-28 | blind fix / blind merge / blind distribution を防ぐ。 | 残す。 | `_AGENTS.md`。 |
| H3 | 質問形式 | 直感的な probe にし、分析を強制しない。 | 32-39 | HitL 質問の質を制御する。 | 残す。Decision Policy に統合。 | `_AGENTS.md`。 |
| E1 | 根拠優先 | 実装・設計判断前に一次ソースを読む。 | 41-55 | 推測による設計判断を防ぐ。 | 残す。tool-neutral に書き直す。 | `_AGENTS.md`。 |
| E2 | 根拠優先 | source priority は code、official docs、community。 | 45-51 | 調査の優先順位を定義する。 | 残す。 | `_AGENTS.md`。 |
| E3 | 根拠優先 | 根拠なし断定を避け、推測は明示する。 | 53-55 | 回答品質を上げる。 | 残す。 | `_AGENTS.md`。 |
| S1 | 技術既定 | frontend/API は TypeScript、backend/systems は Rust。 | 61-63 | repo が指定しない場合の個人 default。 | 残す。ただし fallback と明記。 | `_AGENTS.md`。 |
| S2 | Git 既定 | Conventional Commits の type list。 | 65-67 | commit preference。 | 残す。ただし repo `AGENTS.md` と重複を減らす。 | `_AGENTS.md` + repo 固有 detail は root `AGENTS.md`。 |
| R1 | agent 体制 | Claude は orchestrator、Codex は実作業。 | 69-75 | 過去の multi-agent 運用モデル。 | 消す、または歴史 docs に移す。 | 常時ロードしない。必要なら `docs/plans/` または workflow skill。 |
| R2 | agent 体制 | `codex:rescue` 命名注意。 | 76-79 | 過去の命名混同回避。 | 消す。 | まだ必要なら tool-specific docs。 |
| R3 | agent 体制 | Codex token 切れ時は Claude fallback。 | 81 | 過去の fallback。 | 消す。 | shared instruction には不適。 |
| W1 | workflow | 非自明 task は brainstorm -> plan -> work -> review -> compound。 | 83-85 | preferred process を固定する。 | 書き直す。 | `_AGENTS.md` には「非自明 task は right-sized plan/work/review」を置き、詳細 flow は skill。 |
| W2 | workflow | 設計・計画 80% / 実装 20%。 | 87 | slogan 的な比率。 | 消す。 | 行動改善の再現性が低い。 |
| W3 | workflow | 3 file 以上は `/workflows:plan` 必須。 | 88 | hard process gate。 | 消す、または workflow skill へ移す。 | global には硬すぎ、tool-specific。 |
| W4 | workflow | 解決後に `/workflows:compound`。 | 89 | knowledge workflow trigger。 | Knowledge policy に書き直す。 | `_AGENTS.md` は「非自明知見を記録」に留め、詳細は skill。 |
| P1 | 回答構造 | 計画/整理/次 step 依頼では既知情報から構造化回答。 | 91-93 | planning answer を速くする。 | 残す。Decision/Response policy に統合。 | `_AGENTS.md`。 |
| T1 | tool 選択 | Glob/Grep/Read/Edit/Write を shell より優先。 | 95-103 | Claude Code dedicated tool 前提。 | 書き直す。 | 「利用可能な semantic/project tool を優先。shell が適切なら高速な local search/read を使う」にする。 |
| T2 | tool 選択 | hook-blocked command を parallel Bash に混ぜない。 | 105-107 | 古い Claude hook workaround。 | 消す、または Claude-specific troubleshooting へ移す。 | shared global には不要。 |
| T3 | tool 選択 | compound-engineering の subagent trigger 表。 | 109-113 | 古い subagent routing。 | 消す。 | agent routing は現在の skill/agent metadata に任せる。 |
| Q1 | review 品質 | Severity / Efficiency / Reuse / Quality。 | 115-117 | review lens。 | 残す。少し書き直す。 | `_AGENTS.md` または code-review skill。 |
| M1 | MCP economy | MCP payload を context に全文転写しない。 | 119-125 | context/cache 汚染を減らす。 | 残す。短く書き直す。 | `_AGENTS.md`。 |
| M2 | MCP economy | write call は id/url/success のみ言及。 | 123 | 具体的な出力 rule。 | 残す。 | `_AGENTS.md`。 |
| M3 | MCP economy | read call は必要 field のみ参照。 | 124 | 具体的な context rule。 | 残す。 | `_AGENTS.md`。 |
| M4 | tool call economy | 同一 args の重複 tool call を避ける。 | 127-130 | noisy retry を防ぐ。 | 残す。一般化する。 | `_AGENTS.md`。 |
| M5 | tool call economy | 同じ MCP server への並列発火を可能なら serialize。 | 131 | network/cache duplication を防ぐ。 | 残す。短縮。 | `_AGENTS.md`。 |
| E4 | edit 規律 | 編集前に現内容を読む。 | 133-135 | stale edit を防ぐ。 | 残す。 | `_AGENTS.md`。 |
| E5 | edit 規律 | `old_string` は Nix/TSX anchor 付きで unique にする。 | 136-138 | Claude Edit tool 固有の安定化。 | 書き直す。 | `_AGENTS.md`: unique context で anchor する。Nix detail は repo `AGENTS.md`。 |
| E6 | edit 規律 | 複数変更は 1 回の edit にまとめる。 | 139 | partial patch を減らす。 | 残す。ただし柔らかくする。 | `_AGENTS.md`。 |
| E7 | retry 規律 | 2 回失敗したら re-read して別 approach。 | 140 | blind retry を防ぐ。 | 残す。 | `_AGENTS.md`。 |
| E8 | retry 規律 | 同形 Bash retry は出力分析後。 | 141 | command spam を防ぐ。 | 残す。 | `_AGENTS.md`。 |
| K1 | knowledge | `~/obsidian/` vault を使う。 | 143-145 | 個人 knowledge system。 | 現役なら残す。そうでなければ user docs へ移す。 | 個人/global なので `_AGENTS.md`。 |
| K2 | knowledge | `/know` は非自明知見だけ記録。 | 147-149 | knowledge capture policy。 | slash-command 依存をなくして書き直す。 | `_AGENTS.md`。command detail は skill。 |
| K3 | knowledge | vault search は明示指示時のみ。 | 151-153 | 不要な vault search を防ぐ。 | 残す。 | `_AGENTS.md`。 |

## ブレスト用の評価軸

この段階では具体的な `_AGENTS.md` の完成案を固定しない。先に以下の評価軸で、各指示を残すか・書き直すか・別機構へ移すか・消すかを判断する。

| 評価軸 | 問い | 良い状態 | 悪い状態 | 主な判断 |
| --- | --- | --- | --- | --- |
| Scope | その指示は全 repo / 全 agent で毎回必要か。 | cross-project で常に効く。 | repo 固有、tool 固有、一時的、歴史的。 | cross-project なら `_AGENTS.md`、それ以外は repo docs / tool config / history docs。 |
| Portability | Claude / Codex / 他 agent に同じ意味で通じるか。 | tool-neutral な言葉で書ける。 | `Read` / `Edit` / slash command / subagent 名など特定 harness 依存。 | tool-neutral に rewrite。無理なら tool-specific mechanism へ移す。 |
| Behavioral impact | その指示は実際の行動を変えるか。 | 失敗回避、確認条件、検証、source reading などに効く。 | slogan、価値観表明、既に model/system が自然に行うこと。 | 行動を変えないものは削除。 |
| Specificity | 曖昧でなく実行可能か。 | 「いつ」「何を」「どこまで」が明確。 | 「品質高く」「丁寧に」「best practice」だけ。 | 具体化できるなら rewrite、できないなら削除。 |
| Freshness | 現在の toolchain / repo 方針に合っているか。 | 現行の Home Manager / Codex / Claude / skill 配布と一致。 | 旧 plugin、旧 subagent 名、削除済み workflow に依存。 | stale なものは削除または historical note へ移す。 |
| Enforceability | 自然言語で持つべきか、機械的に強制すべきか。 | 判断・方針・例外処理は文書にある。 | format、lint、permission、secret access などを文章で強制している。 | deterministic なものは hooks / settings / scripts / CI へ移す。 |
| Context cost | 常時ロードする価値が token cost を上回るか。 | 短く、頻繁に使い、誤動作を減らす。 | 長い、まれ、参照で足りる、他 docs と重複。 | 常時必要な index だけ残し、詳細は progressive disclosure。 |
| Human control | user の理解・承認・責任分界を助けるか。 | 非自明判断、未読承認、risky merge/push を適切に止める。 | 何でも確認する、または何でも自動化する。 | ask/execute boundary と comprehension retention は残す。 |
| Evidence quality | source-first decision を支えるか。 | code / official docs / cited source に誘導する。 | 推測や一般論だけで判断できるように見せる。 | source-first は残す。source が不要な一般論は削る。 |
| Maintainability | 今後の更新責務が明確か。 | source of truth が一箇所で、重複がない。 | `AGENTS.md` / `CLAUDE.md` / skills / settings に同じ rule が散らばる。 | 重複を解消し、source of truth を決める。 |

## 評価軸にもとづく判定ルール

| 判定 | 条件 | 例 |
| --- | --- | --- |
| 残す | cross-project、tool-neutral、行動を変える、短く書ける。 | ask/execute boundary、source-first、retry discipline、MCP payload economy。 |
| 一般化して書き直す | 価値はあるが tool 固有名や硬すぎる条件に依存している。 | `Read/Grep/Edit` 優先、`AskUserQuestion`、Nix/TSX 固有 edit anchor。 |
| 別の仕組みに移す | 毎回読む必要がない、または natural language より強い実装手段がある。 | workflow detail は skills、format/test は hooks/CI、permission は settings。 |
| 消す | stale、重複、slogan、過去の事故対応で今は不要、行動を変えない。 | Claude/Codex role division、rescue naming、80/20 比率、古い subagent trigger。 |

## ブレストで追加確認したい観点

- 共有 `_AGENTS.md` は「個人の行動原則」までに留めるか、「agent 操作 discipline」まで含めるか。
- source-first / comprehension retention のような強い方針を、global に置くか repo `AGENTS.md` に置くか。
- Obsidian knowledge workflow は cross-project 指示として常時ロードする価値があるか。
- `CLAUDE.md` と root `AGENTS.md` の drift を、import / symlink / 片方削除のどれで解消するか。

## item-level action plan

| Action | 対象 |
| --- | --- |
| `_AGENTS.md` に短い文で残す | D1-D6, H1-H3, E1-E3, S1-S2, P1, Q1, M1-M5, E4-E8, K1-K3 |
| 一般化して書き直す | D5, W1, T1, E5, K2 |
| project `AGENTS.md` または repo docs に移す | E5 の Nix-specific edit anchoring、repo 固有の commit/test/build command、dotfiles maintenance workflow |
| skills/workflows に移す | W1-W4 の詳細な brainstorm/plan/work/review/compound process |
| settings/hooks/scripts に移す | permission policy、format/test enforcement、secret access、deterministic automation |
| 消す | R1-R3, W2-W3, T2-T3 |

## risk と follow-up decision

- `CLAUDE.md` と `AGENTS.md` が現在は別々に dotfiles repo を説明している。Anthropic は repo が `AGENTS.md` を使う場合、`CLAUDE.md` から import するか symlink することを推奨している。別管理を続けると drift risk がある。
- `_AGENTS.md` は Home Manager 経由で Claude と Codex の両方に注入されるが、現状は片方にしか通じない tool 名や command が混ざっている。shared global guidance は意図して product-specific にする場合を除き、tool 固有名を避けるべき。
- root `AGENTS.md` は preference log、browser tooling、Grepika docs、Nix style、maintenance workflow まで含んでいて大きい。repo 固有なので `_AGENTS.md` より妥当だが、常時ロードされる project instruction としてはまだ大きい可能性がある。別 pass で、常時必要な repo fact と長い reference/history/tool doc を分割する。

## ブレストで決める評価軸の優先順位

ブレスト段階では、具体的な判定・rewrite draft・移行計画には入らない。ここで決めるのは評価軸の優先順位だけにする。

推奨優先順位:

1. Scope
2. Portability
3. Behavioral impact
4. Context cost
5. Enforceability
6. Human control
7. Evidence quality
8. Freshness
9. Maintainability
10. Specificity

この優先順位を前提に、各項目の残す/書き直す/移す/消すの判定は次の計画フェーズで扱う。

## 計画フェーズ: 具体判定

評価軸の優先順位を適用すると、`_AGENTS.md` は「常時ロードする個人の行動原則」として残し、tool-specific な操作手順、古い agent routing、長い workflow は外すのがよい。

採用する方針:

1. `_AGENTS.md` は Claude / Codex / 他 agent で意味が変わらない短い原則に限定する。
2. source-first、ask/execute boundary、comprehension retention、retry discipline、MCP economy は実行品質に直接効くので残す。
3. `Read` / `Edit` / `AskUserQuestion` / slash command / specific subagent 名は、tool-neutral な言い方へ置換する。
4. `brainstorm -> plan -> work -> review -> compound` の詳細は、常時ロードではなく skill / workflow docs に寄せる。
5. format/test/permission/secret access のような deterministic enforcement は AGENTS.md ではなく settings / hooks / scripts / CI に寄せる。
6. Claude/Codex role division、rescue naming、古い compound-engineering subagent trigger は削除する。

却下する方針:

| 方針 | 却下理由 |
| --- | --- |
| 現状 `_AGENTS.md` を微修正だけで残す | stale な tool 名と workflow gate が残り、shared instruction の portability が改善しない。 |
| repo `AGENTS.md` へ全量移す | cross-project な個人方針と dotfiles 固有情報が混ざり、repo instruction がさらに肥大化する。 |
| すべて skill 化する | ask/execute boundary や source-first は常時効くべき原則で、必要時呼び出しだと遅い。 |
| Claude / Codex ごとに別文書を作る | 現在の問題は tool-specific detail の混入であり、分岐を増やすと drift risk が上がる。 |

## 計画フェーズ: `_AGENTS.md` rewrite draft

以下は `home/agents/_AGENTS.md` の置き換え案。意図は「短く、tool-neutral、毎 session 必要な行動原則」にすること。

```markdown
## Intent-First Work

- Ask only when intent, risk, or contract boundary is unclear. If context gives the goal and constraints, proceed.
- Execute obvious direct instructions without approval. Ask before non-obvious design decisions, API/schema/interface changes, destructive actions, or publishing.
- For non-obvious choices, state the chosen option, rejected option, and trade-off briefly.
- After the user answers a blocking question, continue with the next action without re-confirming the same decision.

## Human Understanding

- Do not let the human approve unread non-obvious plans, generated code, risky fixes, merges, pushes, or distribution steps.
- When the request signals blind delegation, give the core implication in one line and ask for a simple preference or confirmation.
- Ask probes that are easy to answer from intuition; do not require analysis unless analysis is the task.

## Source-First Decisions

- Read the relevant source before making implementation or design claims.
- Prefer sources in this order: code, official docs, then community material.
- Cite the concrete source when the decision depends on it. If no source is available, say that the statement is an inference.

## Defaults

- Prefer TypeScript for frontend/API work and Rust for backend/systems work when the repo does not already decide.
- Use Conventional Commits by default: `fix:`, `feat:`, `chore:`, `docs:`, `refactor:`, `test:`.
- When asked for planning, organization, or next steps, answer first from known context in a structured list or table before doing extra file reads.

## Tools And Context

- Prefer precise project-aware tools for search, reading, and edits when available; otherwise use fast local commands and small, targeted reads.
- Keep tool output out of the conversation unless it matters. For write/create/update calls, mention only success and stable identifiers such as path, id, or url.
- Avoid duplicate tool calls with the same arguments. If a call fails or output is surprising, analyze it before retrying.
- Serialize calls to the same remote/MCP server when parallelism mainly duplicates network and context cost.

## Editing And Retry Discipline

- Read the current content before editing it.
- Anchor edits with enough unique surrounding context to avoid touching the wrong block.
- Batch related edits when that reduces partial-state risk.
- After two failed edit attempts, re-read and switch approach instead of repeating the same operation.
- Do not repeat the same shell command unchanged unless the previous output explains why that is useful.

## Reviews

- In reviews, lead with findings. Judge impact through severity, efficiency, reuse, and quality.
- If there are no findings, say so and name any residual verification risk.

## Knowledge

- Record non-obvious, reusable learnings in the knowledge system when they are not already covered by official docs.
- Search the personal vault only when explicitly asked or when the user asks whether prior knowledge exists.
```

この draft で削ったもの:

- Claude / Codex の役割分担。
- `codex:rescue` 命名注意。
- `brainstorm -> plan -> work -> review -> compound` の詳細な固定フロー。
- 3 ファイル以上なら `/workflows:plan` 必須という hard gate。
- dedicated tool 名 (`Read`, `Grep`, `Edit`, `AskUserQuestion`) の直接指定。
- hook-blocked command の古い workaround。
- compound-engineering subagent trigger 表。
- `/know` など slash-command 名への依存。

## 計画フェーズ: 移行先マップ

| 移行対象 | 移行先 | 作業 |
| --- | --- | --- |
| `_AGENTS.md` の cross-project 原則 | `home/agents/_AGENTS.md` | 上記 draft へ置換する。 |
| workflow 詳細 | APM 管理の skill / workflow docs | `ce-*` / Matt Pocock skills に寄せ、常時文書には routing だけ残す。 |
| repo 固有 Nix edit anchor、nixfmt、flake check | root `AGENTS.md` | 既存の dotfiles ルールへ集約する。 |
| Claude-only 設定 | `home/agents/claude-code.nix` または Claude settings | model、permission、hook、Claude 固有 memory 方針へ寄せる。 |
| Codex-only 設定 | `home/agents/codex.nix` または Codex config | sandbox、approval、Codex-specific features へ寄せる。 |
| MCP payload economy | `_AGENTS.md` | tool-neutral な context discipline として残す。 |
| Obsidian knowledge policy | `_AGENTS.md` + knowledge skill | 常時文書は最小ルール、具体操作は skill に寄せる。 |
| root `AGENTS.md` と `CLAUDE.md` の drift | 別計画 | `CLAUDE.md` から `AGENTS.md` import / symlink / 生成のどれかを決める。 |

## 計画フェーズ: `_AGENTS.md` 以外への item-level 移行

「削除」は「重要ではない」ではなく、常時ロード文書に残すと害がある、または別の source of truth がすでにある、という意味で使う。削除する項目でも、意思決定の経緯として価値があるものはこの計画文書に残す。運用上まだ必要なものだけを別機構へ移す。

| ID | 現在の内容 | 判断 | 移行先 / 削除先 | 理由 |
| --- | --- | --- | --- | --- |
| R1 | Claude は orchestrator、Codex が実作業。 | 消す。 | 移行しない。履歴はこの計画文書に残す。 | 現在の実行環境では agent 役割は user request と tool availability で決まる。常時指示すると他 agent や単独 Codex 実行で誤誘導になる。 |
| R2 | `codex:rescue` / `codex:codex-rescue` 命名注意。 | 消す。 | 移行しない。再発するなら該当 skill/plugin の README か troubleshooting docs。 | 過去の命名事故対策で、普遍的な行動原則ではない。常時ロードするより、該当機能の近くに置くべき。 |
| R3 | Codex token 切れ時は Claude が直接実行。 | 消す。 | 移行しない。 | 特定 orchestration 前提で、Codex/Claude どちらにも一般化できない。現在の session では user が明示的に切り替える方が正しい。 |
| W1 | 非自明 task は brainstorm -> plan -> work -> review -> compound。 | 一般化して残し、詳細は移す。 | `_AGENTS.md` には「非自明 task は right-sized plan/work/review」。詳細は `ce-*` / Matt Pocock skills。 | flow 自体は有用だが、固定 sequence は task によって重すぎる。 |
| W2 | 設計・計画 80% / 実装 20%。 | 消す。 | 移行しない。 | 比率は slogan で、行動可能な判定基準にならない。必要なら「非自明な設計は先に根拠と trade-off を出す」で代替する。 |
| W3 | 3 ファイル以上は `/workflows:plan` 必須。 | 消す。 | hard gate は移行しない。計画推奨は workflow skill へ。 | ファイル数は複雑さの proxy として粗い。小さな 3 ファイル変更も、大きな 1 ファイル変更もある。tool-specific slash command でもある。 |
| W4 | 問題解決後は `/workflows:compound`。 | 一般化して残し、詳細は移す。 | `_AGENTS.md` には「非自明知見を記録」。具体操作は knowledge/compound skill。 | knowledge capture は有用だが、slash command を常時文書に固定しない。 |
| T1 | Glob/Grep/Read/Edit/Write を shell より優先。 | 一般化して残す。 | `_AGENTS.md`: project-aware tools を優先。repo/tool 固有の実コマンドは root `AGENTS.md` や skills。 | dedicated tool 名は harness 依存。意図だけ残す。 |
| T2 | hook-blocked command を parallel Bash に混ぜない。 | 消す。 | 移行しない。再発時のみ troubleshooting note。 | 過去の hook 実装事故への局所対策。現在の shared instruction に置くと stale workaround になる。 |
| T3 | compound-engineering subagent trigger 表。 | 消す。 | 移行しない。agent routing は APM-installed skill/agent metadata に委譲。 | skill/agent metadata が source of truth。手書き表は drift しやすい。 |
| E5 の Nix/TSX 具体 anchor | Nix は block header、TSX は関数/コンポーネント名を anchor。 | 分割する。 | `_AGENTS.md` には「unique context で anchor」。Nix 詳細は root `AGENTS.md`。TSX 詳細は必要時に frontend skill/docs。 | editing discipline は普遍、言語別 detail は repo/path scoped。 |
| permission / secret access | prompt で permission と secret rule を説明。 | 移す。 | Claude/Codex settings、hooks、managed policy、repo `AGENTS.md` の管理方針。 | 自然言語で守らせるより config と enforcement に寄せる。 |
| format/test enforcement | `nixfmt`、`nix flake check` など。 | repo 側へ移す。 | root `AGENTS.md`、scripts、CI。 | dotfiles 固有で cross-project ではない。 |
| Obsidian `/know` command 名 | `/know` で記録。 | 一般化して残す。 | `_AGENTS.md` は「非自明知見を記録」。具体 command は knowledge skill / Obsidian docs。 | knowledge policy は個人 global だが command 名は tool-specific。 |

## 計画フェーズ: 削除基準

削除する項目は次のどれかを満たす。重要度だけでは消さない。

| 削除理由 | 判定基準 | 対象 |
| --- | --- | --- |
| Stale | 現在の toolchain / APM 配布 / agent metadata と一致しない。 | R1-R3, T3 |
| Too specific | 特定事故・特定 hook・特定 command の workaround。 | R2, T2 |
| Not actionable | 比率や slogan で、実行時の判断基準にならない。 | W2 |
| Better source of truth exists | settings、hooks、CI、skill metadata、repo AGENTS.md で管理すべき。 | W3, T3, permission / format enforcement |
| Harmful as global default | task や agent によって正しい動きが変わる。 | R1, R3, W3 |

削除しても失われない価値:

- R1-R3 は「過去にそういう運用をしていた」という履歴だけなので、この計画文書に残れば十分。
- W2 は具体行動に落ちないため、source-first / trade-off sharing / right-sized planning で置き換える。
- W3 は「複雑な変更では計画する」という意図だけを残し、ファイル数 gate は捨てる。
- T2 は再発したら hook/troubleshooting doc に復活させる。常時ロードには戻さない。
- T3 は APM の skill/agent metadata に追従させる。人間が手書き同期しない。

## 計画フェーズ: 実装手順

1. `home/agents/_AGENTS.md` を draft で置換する。
2. `_AGENTS.md` から削った項目が、必要なら既存 skill / repo `AGENTS.md` / settings に存在するか確認する。
3. `home/agents/claude-code.nix` と `home/agents/codex.nix` は context injection の参照先が変わらないため、原則変更しない。
4. 生成される Claude / Codex context を評価できる範囲で確認する。
5. root `AGENTS.md` の「選好ログ（L）」に、今回確定した shared instruction 方針を反映する。

## 計画フェーズ: 検証基準

- WHEN `home/agents/_AGENTS.md` を置換したとき THEN tool-specific command 名、slash command 名、古い subagent trigger が残っていない。
- WHEN `home/agents/_AGENTS.md` を置換したとき THEN source-first / comprehension retention / retry discipline / MCP economy が短い形で残っている。
- WHEN `home/agents/_AGENTS.md` を置換したとき THEN `programs.claude-code.context` と `programs.codex.context` の参照先は同じまま評価できる。
- WHEN `.nix` を変更しない文書-only 変更なら THEN `nixfmt` は不要で、必要に応じて Markdown の目視確認だけでよい。

## 未確定論点

- Obsidian knowledge workflow を global `_AGENTS.md` に残すか、knowledge skill の trigger だけに寄せるか。
- root `AGENTS.md` と `CLAUDE.md` の drift は、この計画で扱うか、別計画に分けるか。
- `skill-creator` が APM では `skill` という directory 名で入るため、表示名と directory 名のずれを許容するか、wrapper/local copy で `skill-creator` に揃えるか。
