---
title: "docs: Design dotfiles project management model"
type: docs
status: active
date: 2026-05-12
origin: in-conversation ce-brainstorm
---

# docs: Design dotfiles project management model

## Summary

dotfiles repo を「個人環境を運用する personal platform」として管理するための設計モデルを作る。中心は具体構造ではなく、目的、成立条件、owner、評価軸、検証、失敗履歴から設計を更新する制御ループである。ディレクトリ構造、profile 名、Nix module 化の深さ、README 表現は後から変えられる手段として扱う。

---

## Problem Frame

今回の再設計の目的は、単に `engineering/` に数個の文書を置くことではない。software engineering の考え方で、この repo をどう管理し、どう評価し、どう変更に耐えさせるかを設計することである。

具体的なディレクトリ構造、bootstrap/apply/update コマンド、profile 構成を先に固定すると、手段が目的化しやすい。先に必要なのは、後続作業で profile、Nix の責務、native config、machine 差分、設計文書、運用記録を評価できる管理モデルである。

---

## Requirements

- R1. この repo を dotfiles 置き場ではなく personal platform として定義する。
- R2. repo 管理を、目的、成立条件、owner、criticality、maturity、検証、失敗履歴の関係として表現する。
- R3. 目的と成立条件を主要なメンテナンス軸にし、手段は交換可能であることを明示する。
- R4. Nix/native config の責務分担を定義する。Nix は依存・配置・machine 選択・activation・検証を担い、native config は変化の速い tool 設定の source になり得る。
- R5. machine は詳細設定の owner ではなく、採用判断の索引であるというモデルを残す。
- R6. profile の具体名や最終構成を決めずに、profile 評価軸を残す。
- R7. `engineering/` は設計理由、trade-off、invariant、評価軸に集中させ、QA history や運用ログを置かない。
- R8. 現時点の妥協・制限・未確定論点を contract / rubric と分けて記録する。
- R9. README、bootstrap/apply/update 手順、worktree 作成、repo 全体の再構築は今回の docs pass から外す。

---

## Scope Boundaries

- 新しい空 worktree は作らない。
- repo 構造の再編はしない。
- 最終ディレクトリ構造、bootstrap コマンド、apply コマンド、update コマンドは設計しない。
- 具体的な profile inventory は定義しない。説明に必要な例だけ使う。
- native config を Nix 生成へ寄せない。
- QA history、validation log、task progress record を `engineering/` に追加しない。
- `README.md` は更新しない。まず source となる engineering docs を作る。

### Deferred to Follow-Up Work

- `engineering/` 自体の評価軸: `engineering/` に置く文書と、`operations/`、`records/`、`docs/plans/` に置く文書の境界を後続で定義する。
- README concept projection: accepted engineering model を後で日本語 OSS-style concept README に要約する。
- New worktree rebuild: 文書レビュー後に fresh な `wt` worktree を作り、実際の新構成へ反映する。
- Operations/records taxonomy: QA history、validation log、failure log、change log を置く場所と形式を後続で設計する。

---

## Context & Research

### Relevant Code and Patterns

- `AGENTS.md` は、現在の repo を Nix Flakes + Home Manager 前提の構成として説明し、`hosts/`、`home/`、`packages/`、`config/`、`secrets/`、`tools/`、`skills/`、`docs/plans/` の責務を持っている。
- `AGENTS.md` には、具体案を急がず評価軸・判断基準・未確定論点を先に明確にする選好がすでにある。
- `docs/plans/agents-md-classification.md` は、具体 rewrite に入る前に評価軸、判定ルール、risk、follow-up decision を分けた local precedent として使える。

### External References

- `kavinsood/yaos` は `engineering/` に設計理由、trade-off、failure mode を置く。特に `engineering/sync-contract.md`、`engineering/sync-invariants.md`、`engineering/warts-and-limits.md` が参考になる。
- `ryan4yin/nix-config` は、Nix 主体でありながら tool-native config source を残す実用寄りの参考になる。
- `terlar/nix-config` は、module/profile に寄せた成熟後の参考になる。ただし初期構造としてそのままコピーしない。
- Home Manager の `home.file` / `xdg.configFile` は、repo 内 source を user config location へ宣言的に配置する方針と相性がよい。

---

## Key Technical Decisions

- 初回の設計文書は `project-management-model.md`、`platform-contract.md`、`profile-rubric.md`、`warts-and-limits.md` の 4 つにする。`project-management-model.md` が評価軸同士の関係を持ち、残り 3 文書はその具体領域を扱う。
- `assurance-model.md` は作らない。required/optional、失敗の意味、検証可能性は `platform-contract.md` と `profile-rubric.md` に含め、独立させるほど育ったら後で分割する。
- QA history は `engineering/` に置かない。運用証跡が必要になったら別階層を検討する。
- profile 名や directory structure は例としてのみ扱う。残すべき durable content は、profile の目的、評価軸、machine/profile/component/Nix/native config の関係である。
- 文書本文は日本語で書く。この repo の設計判断を自分が読み返すための artifact として優先する。
- 評価軸は横並びリストではなく、制御ループとして書く。目的が成立条件を生み、成立条件が owner/criticality/maturity/検証を要求し、検証や失敗履歴が rubric と contract を更新する。

---

## Open Questions

### Resolved During Planning

- `assurance-model.md` を別文書にするか: しない。現時点では中途半端なので、関心ごとを `platform-contract.md` と `profile-rubric.md` に統合する。
- QA history を `engineering/` に置くか: 置かない。`engineering/` は設計理由と評価軸に集中させる。
- `engineering/` の 3 文書だけで足りるか: 足りない。評価軸同士の関係を扱う上位文書として `project-management-model.md` を追加する。

### Deferred to Implementation

- 各文書の正確な見出しと文体: 書きながら調整する。ただし文書ごとの責務は変えない。
- `engineering/README.md` が必要か: 3 文書を書いた後、navigation pain が出たら検討する。
- `AGENTS.md` に新しい選好を追加するか: 完成文書を読んだ上で、恒久的な repo preference になったものだけ後続で検討する。

---

## Output Structure

```text
engineering/
  project-management-model.md
  platform-contract.md
  profile-rubric.md
  warts-and-limits.md
```

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
project-management-model.md
  owns: relationship between purpose, success conditions, owners, checks, maturity, and feedback
  feeds: platform-contract.md, profile-rubric.md, warts-and-limits.md

platform-contract.md
  owns: project purpose, non-goals, source/output boundary, Nix/native config responsibility split
  feeds: profile-rubric.md, warts-and-limits.md

profile-rubric.md
  owns: why profiles exist, what a profile represents, how to evaluate profile boundaries
  uses: purpose and success conditions from project-management-model.md and platform-contract.md

warts-and-limits.md
  owns: current compromises, intentionally deferred decisions, known weak spots
  protects: the contract and rubric from silently becoming false claims
```

依存方向は一方向に保つ。management model が評価軸の関係性を定義し、contract が platform の約束を定義し、rubric が profile 境界を評価し、warts/limits が過剰な約束を防ぐ。具体構造、machine file、Nix module 名は後続の実装詳細である。

中心の制御ループ:

```text
目的
  -> 成立条件
  -> owner / criticality / maturity
  -> 検証・観測
  -> 失敗・迷い・運用知見
  -> 評価軸と contract の更新
```

---

## Implementation Units

### U1. Add Project Management Model

**Goal:** repo 管理全体を、目的・成立条件・評価軸・検証・フィードバックの関係として説明する上位文書を作る。

**Requirements:** R1, R2, R3, R7, R9

**Dependencies:** None

**Files:**
- Create: `engineering/project-management-model.md`

**Approach:**
- この repo を「dotfiles collection」ではなく「個人環境を machine 横断で成立させる personal platform」として扱う理由を書く。
- 評価軸の関係を制御ループとして定義する: 目的 -> 成立条件 -> owner/criticality/maturity -> 検証 -> 失敗/迷い/運用知見 -> 評価軸更新。
- 固定したいものと変えてよいものを分ける。固定したいものは目的、成立条件、owner、検証可能性。変えてよいものは structure、profile 名、実装手段、Nix module 化の深さ。
- この文書が具体構造ではなく、後続設計を評価するための meta-model であることを明示する。

**Patterns to follow:**
- `docs/plans/agents-md-classification.md` の評価軸先行の姿勢。
- YAOS engineering docs の contract / invariants / limits の分離。

**Test scenarios:**
- Test expectation: none -- docs-only change with no executable behavior.

**Verification:**
- 文書が、なぜ評価軸を作るのか、評価軸同士がどう関係するのかを説明している。
- 手段を固定せず、目的と成立条件を固定する方針が明確である。
- profile だけでなく repo/project management 全体を対象にしている。

---

### U2. Add Platform Contract

**Goal:** project 全体の目的、約束、非目的を定義する engineering contract を作る。

**Requirements:** R1, R3, R4, R5, R9

**Dependencies:** U1

**Files:**
- Create: `engineering/platform-contract.md`

**Approach:**
- repo を machine 横断の個人環境を管理する personal platform として定義する。
- 中心原則として「目的と成立条件を保ち、手段はより良いものへ変えられる」を書く。
- Nix の責務を、依存、配置、activation、machine 選択、検証として定義する。
- native config は tool 固有で変化の速い設定の source になり得ると定義する。
- `~/.config` などの出力先は source ではなく result として扱う。
- non-goals に branch-per-machine、config 側からの Nix 評価、偶然 PATH 依存、初期段階での full Nix-module 化、bootstrap command 設計を含める。

**Patterns to follow:**
- `docs/plans/agents-md-classification.md` の評価軸と言語化の粒度。
- YAOS `sync-contract.md` の promise / non-promise framing。

**Test scenarios:**
- Test expectation: none -- docs-only change with no executable behavior.

**Verification:**
- 文書が「なぜこの repo が存在するか」「Nix と native config が何を owner とするか」を日本語で説明できる。
- 具体的な bootstrap/apply/update 手順を含まない。
- source path と output path を区別している。

---

### U3. Add Profile Rubric

**Goal:** profile を置く目的と、profile 境界を継続的に評価・改善する軸を文書化する。

**Requirements:** R2, R5, R6, R7

**Dependencies:** U1, U2

**Files:**
- Create: `engineering/profile-rubric.md`

**Approach:**
- profile を tool bucket ではなく、環境能力の成立条件を表す単位として定義する。
- machine、profile、component/program/service、Nix、native config の関係を説明する。
- ブレストで出た rubric 軸を残す: 目的、成立条件、失敗の意味、machine からの選択可能性、owner の明確さ、変更理由のまとまり、代替可能性、観測/検証可能性、成熟度。
- profile 追加・変更時に rubric を通し、実運用で迷ったケースから rubric 自体を更新する方針を書く。
- 最終 profile 名は決めない。例は評価軸の理解補助としてのみ使う。

**Patterns to follow:**
- `docs/plans/agents-md-classification.md` の rubric table style。
- `terlar/nix-config` の profile-oriented structure。ただし taxonomy はコピーしない。

**Test scenarios:**
- Test expectation: none -- docs-only change with no executable behavior.

**Verification:**
- 評価軸の前に、profile を置く目的が説明されている。
- 各 rubric 軸に「何を問うか」と「どんな破綻を検出するか」がある。
- concrete profile composition は意図的に deferred であると分かる。

---

### U4. Add Warts and Limits

**Goal:** contract と rubric が過剰に約束しないよう、現時点の妥協、制限、未確定論点を記録する。

**Requirements:** R3, R7, R8, R9

**Dependencies:** U1, U2, U3

**Files:**
- Create: `engineering/warts-and-limits.md`

**Approach:**
- 現時点の妥協を記録する: native config を source として残す、generator/module 化は defer、profile taxonomy は未確定、`engineering/` 自体の評価軸は未完、README/worktree/bootstrap は scope 外。
- intentional trade-off と unresolved question を分ける。
- limit は恥や backlog noise ではなく、current truth として書く。
- 運用ログや QA history は入れず、設計解釈に影響する制限だけを書く。

**Patterns to follow:**
- YAOS `warts-and-limits.md` の fact-first compromises と explicit non-goals。

**Test scenarios:**
- Test expectation: none -- docs-only change with no executable behavior.

**Verification:**
- 少なくとも 1 つの intentional compromise と 1 つの deferred decision がある。
- platform contract や profile rubric の全文を重複していない。
- session-style QA history を含まない。

---

### U5. Review Cross-Document Consistency

**Goal:** 4 文書を独立したエッセイではなく、1 つの project management model として読める状態にする。

**Requirements:** R1, R2, R3, R6, R7, R8

**Dependencies:** U1, U2, U3, U4

**Files:**
- Modify: `engineering/project-management-model.md`
- Modify: `engineering/platform-contract.md`
- Modify: `engineering/profile-rubric.md`
- Modify: `engineering/warts-and-limits.md`

**Approach:**
- "purpose"、"success conditions"、"owner"、"criticality"、"maturity"、"machine"、"profile"、"component"、"native config"、"output" の用語を揃える。
- 関係性を明確にする: `project-management-model.md` は評価軸の関係性、`platform-contract.md` は約束、`profile-rubric.md` は profile 境界の評価、`warts-and-limits.md` は過剰な約束の防止。
- 後でメンテしづらくなる重複段落を削る。
- 具体例が committed structure として読めないか確認する。

**Patterns to follow:**
- YAOS engineering docs の contract / invariant-like rules / limits の分離。

**Test scenarios:**
- Test expectation: none -- docs-only consistency pass.

**Verification:**
- project management model、platform promise、profile 評価軸、known compromise を変えるとき、どの文書を編集すべきかが分かる。
- README、bootstrap flow、repo structure が決定済みだと読める記述がない。

---

## System-Wide Impact

- **Documentation surface:** top-level `engineering/` を新設する。`docs/plans/` は実行計画、`engineering/` は durable design rationale として分ける。
- **Repository structure:** 新しい top-level directory は作るが、Nix evaluation、Home Manager module、packages、config placement は変えない。
- **Project management:** 後続の profile 設計、repo structure 設計、README 化、worktree rebuild は、この評価モデルを参照して判断できる。
- **Agent workflow:** 将来の agent は新 dotfiles architecture を設計する前にこの文書を参照できる。ただしこの計画ではまだ `AGENTS.md` へ配線しない。
- **Unchanged invariants:** 既存の Nix files、native configs、secrets、packages、host/home definitions は変更しない。

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| 文書が具体実装案に寄りすぎる | 例は non-binding と明示し、具体構造は future plan に移す。 |
| `engineering/` が雑多な置き場になる | QA history と運用ログを今回の scope から外し、engineering doc rubric は follow-up にする。 |
| Profile rubric が抽象的すぎて使えない | 各軸に「何を問うか」と「どんな破綻を検出するか」を必ず書く。 |
| Project management model が抽象論だけになる | 制御ループと「固定するもの / 変えてよいもの」を必ず含める。 |
| Warts document が contract の重複になる | compromises、limits、deferred decisions に限定する。 |

---

## Documentation / Operational Notes

- 後続実装で `.nix` を触らない限り、`nixfmt` や `nix flake check` は不要。
- Markdown review では、日本語の読みやすさ、概念の一貫性、link integrity を確認する。
- 文書完成後に durable repo preference が見つかった場合、`AGENTS.md` 更新は別 follow-up にする。
- この plan 自体は project management design の計画であり、`engineering/` のファイル追加はその設計を残す手段である。手段が目的化していないかを review で確認する。

---

## Sources & References

- Origin: in-conversation `ce-brainstorm` on the dotfiles redesign concept.
- Local guidance: `AGENTS.md`
- Local precedent: `docs/plans/agents-md-classification.md`
- External reference: `https://github.com/kavinsood/yaos/tree/main/engineering`
- External reference: `https://github.com/kavinsood/yaos/blob/main/engineering/sync-contract.md`
- External reference: `https://github.com/kavinsood/yaos/blob/main/engineering/sync-invariants.md`
- External reference: `https://github.com/kavinsood/yaos/blob/main/engineering/warts-and-limits.md`
- External reference: `https://github.com/ryan4yin/nix-config`
- External reference: `https://github.com/terlar/nix-config`
- External reference: `https://home-manager.dev/`
