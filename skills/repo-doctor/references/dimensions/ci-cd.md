# 次元8: CI/CD

第2の防御層。local で回る決定論的チェックの再確認と、hook では遅すぎる全体スキャンを担う。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| CI 設定が存在する | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `bitbucket-pipelines.yml` | 1つ以上存在 |
| テストがlocalでも実行できる | `just`, package scripts, documented command からテスト実行 | local 実行パスあり |
| lint/format がlocalでも実行できる | `just`, package scripts, documented command から lint/format 実行 | local 実行パスあり |
| テストがCIで実行される | CI設定内にテスト実行コマンド | 参照あり |
| lint/format チェックがCIで実行される | CI設定内にlinter/formatterの実行 | 参照あり |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| セキュリティスキャンがCIに統合 | SAST (Semgrep/CodeQL), Secret検知, SCA の CI 参照 | 1つ以上統合 |
| カバレッジレポートがPRに表示 | Codecov, Coveralls, SonarCloud の PR コメント設定 | 設定あり |
| Quality Gate が設定 | SonarQube/SonarCloud Quality Gate, カバレッジ閾値, lint error = fail | PRをブロックする設定あり |
| ビルドキャッシュ活用 | `actions/cache`, Nix cache, Docker layer cache | キャッシュ設定あり |
| 並列実行 | テスト分割、マトリクスビルド、ジョブ並列化 | 並列設定あり |
| Nix Flake check（Nix使用時） | `nix flake check` がCIで実行 | Nix使用時にCI実行あり |
| local と CI の主要チェックが一致 | `just test` と CI の `just test`、同等 command の mirror を確認 | CI-only ではない |
| PRごとの差分スキャン | SAST/lint が変更ファイルのみ対象（速度最適化） | 差分対象の設定あり |
| local と CI の共有コマンドを `just` に抽出 | `justfile` / `Justfile` が存在し、CI から `just <recipe>` を実行 | 30文字超の共有コマンドが recipe 化 |

## CIパイプライン構成の理想形

```
local default
  ├─ lint + format check
  ├─ type check
  ├─ secret scan
  ├─ dead-code check
  └─ test

PR opened
  ├─ [並列] local recipes の再実行（lint / type / test）
  ├─ [並列] secret scan / SAST
  ├─ [順次] coverage report
  ├─ [順次] build → artifact
  └─ [条件] container scan / 全体スキャン

merge to main
  ├─ 全テスト実行（flaky含む、必要なら matrix）
  ├─ SCA (Trivy/Snyk)
  └─ SBOM生成（リリース時）
```

### 重要原則

- **並列化**: 独立したチェックは並列実行（SAST + secrets + lint 同時）
- **local-first parity**: 主要チェックは local から先に回せること。CI は同じ command / recipe の再実行を優先する
- **差分スキャン**: 変更ファイルのみ対象で速度を維持（全体スキャンは定期実行）
- **Fail-fast**: critical/high severity のみブロック。info/low は通知のみ
- **PRコメント**: 検出結果をインラインコメントでPRに表示（別ダッシュボードは見られない）
- **コマンド共有**: local と CI で同じ長いコマンドを繰り返すなら `just` に抽出して重複を避ける

## GitHub Actions 固有

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| actions のバージョンピン | `uses:` がフル SHA で pin され、元の tag / version が comment 等で追跡可能 | full SHA pin |
| `GITHUB_TOKEN` の最小権限 | `permissions:` ブロックでスコープ制限 | permissions 明示 |
| `pull_request_target` の安全な使用 | `pull_request_target` で checkout する場合 head ref を使っていない | 安全な使用 |

## 判定基準

| スコア | 条件 |
|--------|------|
| A | test/lint/format の local parity + CI 再確認 + security scan + quality gate + カバレッジPR表示 + キャッシュ + 並列化 + action full SHA pin |
| B | test/lint/format の local 実行パス + CI 再確認 + PRブロック設定 + action full SHA pin |
| C | CI存在するが local parity が弱い、またはCI側で lint/security が未統合 |
| F | CI未設定、またはCIがあるが実質的なチェックなし |
