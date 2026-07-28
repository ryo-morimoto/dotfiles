# `rigorous-naming` のライセンス・来歴監査

調査日: 2026-07-28

対象:

- ローカル Skill: `ryo-morimoto/skills/skills/rigorous-naming/`
- 比較元: `kawasima/evolutionary-naming` の commit [`dcd3e0133114ee14f7a82220ba530997d6c44da9`](https://github.com/kawasima/evolutionary-naming/commit/dcd3e0133114ee14f7a82220ba530997d6c44da9)

これは法的意見ではなく、公開リポジトリで安全に再利用するための保守的なライセンス遵守判断である。

## 結論

「上流の文章やファイルを逐語的にコピーしていないため、独立著作であり帰属は不要」と言い切るのは適切でない。

現在の Skill は上流と大きく異なる文章・目的・手順を持ち、逐語的コピーの兆候は弱い。しかし、上流を実際に読んだうえで置換対象に選び、上流で kawasima 氏の変更点として明記されている `audit` / `improve` のモード分割を残し、命名の難しさを構造改善へつなげる判断枠組み、call site による intent の評価、値のまとまりから Value Object を疑う設計シグナルなどを選択的に採用している。

したがって、著作権法上の派生著作物に必ず該当すると断定する必要はないが、プロジェクトの来歴管理と CC BY 4.0 遵守の実務では **`evolutionary-naming` を一部翻案した Skill として扱い、帰属する** のが妥当である。帰属コストは小さく、由来を隠して独立著作と主張するリスクと説明コストを避けられる。

Creative Commons 自身も、何が adaptation に当たるかは適用法によるとしており、既存作品に基づく変更が十分な創作性を持つ場合を一般的な adaptation の例としている。アイデアだけを参照したのか、保護される表現・配列・構成を翻案したのかを機械的に線引きできるとはしていない。[Creative Commons FAQ: When is my use considered an adaptation?](https://creativecommons.org/faq/#when-is-my-use-considered-an-adaptation)

## 比較した一次資料

上流の現行 `master` は調査時点で `dcd3e0133114ee14f7a82220ba530997d6c44da9` だった。将来の変更で比較結果が動かないよう、以下はすべてこの commit へ固定した。

- [上流 LICENSE](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/LICENSE)
- [上流 README](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/README.md)
- [上流 SKILL.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/SKILL.md)
- [上流 audit-mode.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/audit-mode.md)
- [上流 improve-mode.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/improve-mode.md)
- [上流 reference.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/reference.md)
- [CC BY 4.0 Legal Code](https://creativecommons.org/licenses/by/4.0/legalcode.en)
- [Creative Commons の帰属ベストプラクティス](https://wiki.creativecommons.org/wiki/Best_practices_for_attribution)

ローカル側は次を EOF まで確認した。

- `skills/rigorous-naming/SKILL.md`
- `skills/rigorous-naming/references/calibration.md`
- `skills/rigorous-naming/references/design-signals.md`
- `skills/rigorous-naming/agents/openai.yaml`

## 上流がライセンス対象として示すもの

上流はリポジトリを CC BY 4.0 とし、`Copyright (c) 2026 kawasima`、CC BY 4.0 のライセンスリンク、再配布・翻案時の帰属と変更表示を明記している。[上流 LICENSE](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/LICENSE#L1-L18)

さらに上流自身が、Arlo Belshee の “Naming as a Process” をもとにし、kawasima 氏による変更として Claude Code Skill 化、`audit` / `improve` モード、phase-boundary safety gate、TDD 由来の anti-pattern を加えたと説明している。[上流 LICENSE](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/LICENSE#L20-L28) [上流 README](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/README.md#L82-L92)

この由来表示は重要である。一般的な「良い名前を付ける」「call site を読む」というアイデアと、kawasima 氏が Skill として選択・構成した具体的なモード、ルーティング、停止条件、ファイル分割は分けて比較する必要がある。

## 共通点

| 観点 | 上流 | ローカル Skill | 監査判断 |
|---|---|---|---|
| モード構成 | `audit-mode` は広い監査、`improve-mode` は特定の1識別子を改善する。[上流 SKILL.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/SKILL.md#L25-L47) | `Audit` と `Improve` を残し、通常実装用の `Embedded` を追加している。 | **強い構成上の共通点。** `audit` / `improve` は上流が自身の変更として名指しした部分であり、帰属判断で無視しない。 |
| audit の非変更性 | 指定範囲をレポートし、変更せず表を出して止まる。[上流 audit-mode.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/audit-mode.md#L7-L22) | ユーザーが指定した範囲だけを監査し、編集せず、後続依頼では Improve へ切り替える。 | **中程度の構成上の共通点。** 出力形式と分類法は異なるが、モードの責務と境界は対応する。 |
| 命名困難を設計シグナルとして扱う | 長い完全名から責務分割へ進み、parameter cluster から Whole Value / Value Object を探す。[上流 reference.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/reference.md#L92-L143) | 長い honest name、複数 action、繰り返しまとまる parameter/field を mixed responsibility や missing value object のシグナルにする。 | **概念と選択の共通点。** Fowler 等にもある一般的リファクタリング知識だが、上流参照後に同じ組合せを採用した来歴は明示すべき。 |
| call site と intent | body ではなく全 call site を読み、`what` から `why` へ上げる。[上流 reference.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/reference.md#L126-L139) | 宣言だけでなく代表 call site、test、error、docs に候補を置き、利用箇所で意図と実動作が一致するか評価する。 | **概念上の共通点。** ローカル側は候補比較と複数 surface へ大幅に拡張している。 |
| vague name のシグナル | `Manager`, `Util`, `process`, `handle`, `data` 等を Missing/Misleading の兆候にする。[上流 reference.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/reference.md#L9-L22) | `Manager`, `Util`, `Data`, `Info`, `Item`, `Process`, `Handle` を設計調査のシグナルにする。 | **用語選択が重なる。** ローカル側は blanket ban を否定しており、判断規則は異なる。 |
| progressive disclosure | router 本体と、共通知識・モード別ファイルを分ける。[上流 README](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/README.md#L68-L75) | core procedure を `SKILL.md` に置き、calibration と design signal を条件付き reference に分ける。 | Skill の一般的な設計慣行でもあるが、参照元と同じ課題領域・近い分割のため補助的な共通点になる。 |

ローカルの先行研究メモ自身も、上流 `evolutionary-naming` を置換し、`embedded` / `improve` / `audit` を持つ owned replacement を作る計画を明記している。この来歴からも「上流を見ずに独立して同じ構成へ到達した」とは説明できない。

## 相違点

| 観点 | 上流 | ローカル Skill | 意味 |
|---|---|---|---|
| 主目的 | 命名リファクタリングを段階的に**提案**する advisory Skill。編集・git 実行をしない。[上流 SKILL.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/SKILL.md#L9-L17) | 通常実装に埋め込み、認可された範囲で名前を決定・実装・伝播・検証する。 | 中心的な動作契約は逆であり、ローカル独自の変更が大きい。 |
| 中心手順 | 7 steps / 3 phases: Missing → Nonsense → Honest → Honest and Complete → Does the Right Thing → Intent → Domain Abstraction。[上流 SKILL.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/SKILL.md#L18-L23) | repository search、概念定義、surface 分類、concepts-before-words、2候補比較、design feedback、伝播、再検証の8手順。 | 特徴的な状態遷移を採用しておらず、手順の文章と配列は大幅に再設計されている。 |
| 特徴的表現 | `applesauce`, `probably_`, `_AndStuff`、一段一 commit、phase boundary での pause。[上流 improve-mode.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/improve-mode.md#L9-L67) | いずれも採用していない。local/private は原則自律的に進め、契約・意味の境界だけで確認する。 | 上流で最も識別的な表現と進行 protocol は削除されている。 |
| 対象 surface | 主に code identifier と構造的 refactoring。 | code に加え、API、schema、persistence、config、CLI、event、telemetry、error、test、docs を一貫した語彙として扱う。 | ドメイン語彙と公開契約への独自拡張が大きい。 |
| 公開契約 | phase の permission gate はあるが、compatibility / alias / deprecation / versioning / stored-data migration を中心手順にしていない。 | public/persisted rename を migration work と分類し、consumer と互換性戦略を完了条件にする。 | ローカル独自の重要な追加。 |
| restraint | single-letter name を原則 Missing と診断するが、obvious な場合は直接 Honest へ進む。[上流 reference.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/reference.md#L9-L22) | tiny conventional loop の `i`、generated/vendor、framework prescribed name、term of art には workflow を強制しない。 | blanket rule を抑える独自の scope gate がある。 |
| 具体例 | flight/XML/database、`OrderManager`、`DocumentManager`、`applesauce` が中心。[上流 audit-mode.md](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/skills/evolutionary-naming/audit-mode.md#L24-L59) | payment、expired token、invoice total、`userId` / `accountId` 等で校正する。 | 例の逐語的・具体的転用は確認できない。 |

## 逐語的類似の補助確認

上流の `SKILL.md`、`audit-mode.md`、`improve-mode.md`、`reference.md` と、ローカルの `SKILL.md`、`calibration.md`、`design-signals.md` を小文字化し、英数字・underscore・hyphen からなる token 列として比較した。

- 一致する連続 12-word、10-word、8-word、6-word 列: 0
- 一致する連続 5-word 列: `audit mode if the user` の1件

これは長い逐語コピーが見当たらないことの補助証拠にはなるが、著作権上の判定ではない。短い語句、Markdown 構造、概念の選択・配列、翻案、別表現による再構成は n-gram では評価できない。

## なぜ「帰属不要」ではなく「帰属する」なのか

1. **参照の事実がある。** 上流を読んだうえで、既存 Skill を owned replacement に差し替える設計を行っている。
2. **kawasima 氏の追加部分が残る。** とくに `audit` / `improve` のモード構成は、上流 LICENSE が kawasima 氏の変更として明記した部分である。[上流 LICENSE](https://github.com/kawasima/evolutionary-naming/blob/dcd3e0133114ee14f7a82220ba530997d6c44da9/LICENSE#L20-L28)
3. **選択と組合せが対応する。** vague-name signal、長い名前から構造へ進む分岐、call-site intent、parameter cluster から value object、audit/improve の役割分離が一つの Skill にまとまって残る。
4. **文章の大半が新規でも来歴は消えない。** CC の定義では Adapted Material は licensed material を翻訳、変更、配列、変形その他の形で変更したものを含み得る。ただし、実際に許諾が必要な変更かは適用される著作権法による。[CC BY 4.0 Legal Code, Section 1](https://creativecommons.org/licenses/by/4.0/legalcode.en#s1)
5. **保守的対応の不利益が小さい。** CC BY 4.0 は翻案と商用利用を許しており、求められる中心対応は適切な帰属、ライセンス表示、変更表示である。[CC BY 4.0 Deed](https://creativecommons.org/licenses/by/4.0/)

したがって、「法的に確実に derivative だから」ではなく、「実際の作成経緯と構成上の影響を正直に示し、CC BY 4.0 の許諾条件を満たす最小コストの安全策だから」帰属する。

## 必要な帰属要素

CC BY 4.0 Section 3 は、licensed material を変更した形で共有する場合、提供されている範囲で creator、copyright notice、license notice、warranty disclaimer notice、合理的に可能なら material の URI を保持し、変更したことと従前の変更表示を示し、CC BY 4.0 の本文または URI を含めるよう求める。媒体・方法・文脈に応じた合理的な方法で満たせる。[CC BY 4.0 Legal Code, Section 3(a)](https://creativecommons.org/licenses/by/4.0/legalcode.en#s3a)

この Skill では少なくとも次を残す。

- 原作品名: `evolutionary-naming`
- 作者・帰属先: kawasima
- 原 copyright notice: `Copyright (c) 2026 kawasima`
- 固定した原資料: commit `dcd3e0133114ee14f7a82220ba530997d6c44da9` への URL
- 原ライセンス: CC BY 4.0 の名称とリンク
- 「翻案した」ことの表示
- 変更内容: advisory から embedded execution への変更、7-step/3-phase の置換、対象 surface と compatibility workflow の追加、上流固有 mechanics の削除、Codex 用の再編
- 上流が保持している Arlo Belshee / “Naming as a Process” / CC BY 3.0 の由来と、上流での変更表示
- kawasima 氏や上流 contributor の endorsement を示唆しない表示

Creative Commons の実務ガイドは、Title、Author、Source、License の TASL を基本とし、変更版では変更内容も示す例を提示している。[Creative Commons: Best practices for attribution](https://wiki.creativecommons.org/wiki/Best_practices_for_attribution#This_is_a_great_attribution_for_an_image_you_modified_slightly)

## 推奨する配置とライセンス境界

最も分かりやすい構成は Skill directory 単位である。

```text
skills/rigorous-naming/
├── SKILL.md           # 末尾から ATTRIBUTION と LICENSE を参照
├── ATTRIBUTION.md     # TASL、固定 commit、変更点、上流の由来を記載
├── LICENSE            # この directory が CC BY 4.0 であることと legal code URL
├── agents/openai.yaml
└── references/...
```

repository root の MIT LICENSE だけでは、上流由来部分の CC BY 4.0 条件と来歴が downstream user に伝わらない。nested LICENSE でこの Skill directory の範囲を明確にすれば、root MIT と曖昧に混ぜずに済む。配布・インストール処理が `ATTRIBUTION.md` と `LICENSE` を省かず同梱することも確認する。

全 directory を CC BY 4.0 とするのは、独自寄与まで CC BY 4.0 にする保守的で単純な選択である。独自寄与を MIT、上流由来部分だけを CC BY 4.0 にする二重構造も理論上は可能だが、どの節がどちらかを明示する負担が増え、この小さな文書 Skill では利点が乏しい。CC FAQ も、adaptation では原素材の CC license が残り、adapter's license と両方に downstream recipient が従う必要があると説明している。[Creative Commons FAQ: adapter's license](https://creativecommons.org/faq/#if-i-derive-or-adapt-material-offered-under-a-creative-commons-license-which-cc-licenses-can-i-use)

## 現 worktree の是正状況

監査時点の `ryo-morimoto/skills` worktree では、次がすでに確認できた。

- `skills/rigorous-naming/ATTRIBUTION.md`
  - kawasima 氏、作品名、固定 commit、copyright、CC BY 4.0、原 LICENSE を記載
  - 変更点を5項目で表示
  - upstream の Arlo Belshee / CC BY 3.0 notice を保持
  - endorsement ではないと明記
- `skills/rigorous-naming/LICENSE`
  - directory 全体を CC BY 4.0 と明記し、deed と legal code へリンク
- `skills/rigorous-naming/SKILL.md`
  - 自身を `evolutionary-naming` の adaptation と明記し、上記2ファイルへリンク

この構成は本監査の推奨を満たしている。公開前に次だけ検証する。

1. APM/installer が `ATTRIBUTION.md` と `LICENSE` を配布物へ含める。
2. generated lock または package manifest が nested files を落としていない。
3. GitHub 上の commit permalink が公開後も有効である。
4. Skill directory の全ファイルを CC BY 4.0 とする意図を maintainer が了承している。

## 最終判断

| 問い | 判断 |
|---|---|
| 文章をほぼコピーしたか | いいえ。長い逐語一致や上流固有例の転用は確認できない。 |
| 内容・構成に上流の実質的影響があるか | はい。とくに mode 分割、命名から構造へ進む設計判断、call-site intent、value-object signal の選択に影響がある。 |
| 完全な独立著作として帰属を省略してよいか | 保守的な実務判断では、いいえ。作成来歴にも反する。 |
| どう扱うべきか | `evolutionary-naming` を一部翻案した Skill と明示し、CC BY 4.0 の帰属・ライセンス・変更表示を同梱する。 |
| 現在の nested `ATTRIBUTION.md` / `LICENSE` / Skill 内 notice は十分か | はい。配布物にも3点が残ることを確認すればよい。 |
