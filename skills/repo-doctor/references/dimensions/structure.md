# 次元2: ディレクトリ構造

規模に応じた構造設計があるか。判断の根拠が記録されているか。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| README.md が存在し実質的内容がある | `README.md` の行数 > 10、"TODO" だけでない | 内容あり |
| ソースコードが1ディレクトリに平置きでない（Medium以上） | `src/`, `lib/`, `app/`, `cmd/`, `internal/` 等のサブディレクトリ構造 | LOC > 5,000 なら構造化されている |
| エントリポイントが明確 | `main.ts`, `index.ts`, `main.rs`, `main.go`, `app.py` 等、またはビルド設定から特定可能 | 特定可能 |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| ADR（Architecture Decision Records）が存在 | `docs/decisions/`, `docs/adr/`, `docs/decision-record/`, `adr/` のいずれか | ディレクトリ存在 + 1件以上 |
| CONTRIBUTING.md が存在 | ファイル存在チェック | 存在 |
| テストとソースの分離規約が明確 | テストが `__tests__/`, `tests/`, `spec/`, `*_test.go`, `*_test.rs` 等の規約に従っている | 規約が一貫している |
| モジュール境界が明確（Large） | `packages/`, `crates/`, `services/` 等のワークスペース構造、またはモノレポツール設定 | 構造あり |
| GitHub Community Health Files | `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md` | 存在 |

## 規模別の期待構造

### Tiny (~500 LOC)
```
├── README.md
├── src/        # or ソースファイル直置き（許容）
└── flake.nix   # or 環境定義
```

### Small (~5,000 LOC)
```
├── README.md
├── src/
│   ├── [機能ごとのファイル]
│   └── ...
├── tests/
└── flake.nix
```

### Medium (~50,000 LOC)
```
├── README.md
├── CONTRIBUTING.md
├── docs/
│   └── decisions/     # ADR
├── src/
│   ├── [レイヤーまたはドメインごと]
│   └── ...
├── tests/
│   ├── unit/
│   └── integration/
└── flake.nix
```

### Large (50,000+ LOC)
```
├── README.md
├── CONTRIBUTING.md
├── docs/
│   ├── decisions/
│   └── architecture/
├── packages/          # or crates/, services/
│   ├── [module-a]/
│   └── [module-b]/
├── .github/
│   ├── CODEOWNERS
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
└── flake.nix
```

## 判定基準

| スコア | 条件 |
|--------|------|
| A | 規模に応じた構造 + ADR + CONTRIBUTING + Community Health Files |
| B | 規模に応じた構造 + README が実質的 + テスト分離 |
| C | ソースは構造化されているが文書化が不足、またはテスト配置が不統一 |
| F | 平置き構造で規模に見合わない、または README が不在/空 |
