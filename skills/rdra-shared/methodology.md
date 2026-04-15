# RDRA Methodology (3.0)

RDRA = Relationship Driven Requirement Analysis. 4層 × 3フェーズ × 9ステップで要件を組み立てる。

## 一次ソース

- https://www.rdra.jp/ (ホーム)
- https://www.rdra.jp/article1 (どんな手法)
- https://www.rdra.jp/表形式のrdra定義
- https://www.rdra.jp/要件定義の進め方
- https://www.rdra.jp/既存システムの可視化
- https://note.com/fuutaudis2741/n/nc7683ed5237f (3.0 差分解説、コミュニティ。公式ハンドブック未検証)
- https://note.com/fuutaudis2741/n/nccaaa216bb0e (レイヤ探索順)

## 4 layers

| Layer | Scope | Contents |
|---|---|---|
| システム価値 | なぜ | 要求モデル, システムコンテキスト, アクター, 外部システム |
| システム外部環境 | 誰が何を | ビジネスコンテキスト, BUC (ビジネスユースケース), 業務フロー, 利用シーン |
| システム境界 | 入出力 | UC (ユースケース), 画面, イベント |
| システム | どう保つ | 情報モデル, 状態モデル, 条件, バリエーション |

**RDRA 3.0 注意:** 条件/バリエーションは 3.0 でシステム層に移動した (2.0 では外部環境層扱いだった)。出典は note.com コミュニティ解説で、公式ハンドブックでの確認は未実施。

**Context grouping (3.0 新概念):** システム層の要素を業務単位でグルーピングし、凝集度/結合度を可視化する。`rdra-summary` で使う。

## 3 phases / 9 steps

| Phase | Step | 内容 | 更新するシート |
|---|---|---|---|
| **Phase 1 基盤** | 1 | 登場人物 + 業務起点 | `アクター`, `外部システム` (分離シート) |
|  | 2 | BUC 粗出しでスコープ把握 | `BUC` (A-F 列: 業務/BUC/先/アクティビティ/次/UC) |
|  | 3 | 業務で扱う情報を明示 | `情報` |
|  | 4 | 業務が認識する状態 | `状態` |
| **Phase 2 要件形成** | 5 | トップダウンで UC 組立 + 要求抽出 | `BUC` (F 列 UC), `機能要求`, `非機能要求` |
|  | 6 | アクター/情報/状態/外部システムを UC に紐付け | `BUC` G-J 列 (generic relation: 関連モデル1/2 × 関連オブジェクト1/2) |
| **Phase 3 仕様化準備** | 7 | UC に紐づく条件を洗い出す | `条件` |
|  | 8 | 条件軸でバリエーション抽出 | `バリエーション` |
|  | 9 | 条件 × バリエーションを詳細化 (Context で結線) | 全 source sheet の `コンテキスト` 列 |

## Core invariants (全skill共通の前提)

1. **Layer traversal order:** Value → External → System → Boundary。境界は最後ではなく、各フェーズで価値/外部から橋渡しされる。
2. **"Why" 依存は上向き:** System が Boundary を正当化し、Boundary が External を、External が Value を正当化する。下流編集は上流の正当化を壊さないこと。
3. **Iterate, don't complete:** 単一シートの完成を追わず、全体のつながりを意識して精度を徐々に上げる。(rdra.jp/表形式)
4. **Phase 1 time-box ≈ 10%:** プロジェクト総期間の約1割で Phase 1 を切り上げる。20日案件なら2日。
5. **Phase 2 gate:** UC が特定され、見積もり可能になったら Phase 2 終了。成熟チームはここで停止し設計へ進む選択肢がある。
6. **Name-based cross-referencing:** シート間は ID ではなく名前の完全一致で結合する。名前ズレ = 不整合。

## RDRA が対処する失敗モード

rdra.jp/要件定義の進め方 より:

- 目的不明
- ゴール曖昧
- 議論のデッドロック
- 思いつきの羅列
