# 次元8: CI/CD

第2の防御層。pre-commit hookが見逃した問題、hookでは遅すぎるチェック、全ファイル対象のスキャンを担う。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| CI 設定が存在する | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `bitbucket-pipelines.yml` | 1つ以上存在 |
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
| PRごとの差分スキャン | SAST/lint が変更ファイルのみ対象（速度最適化） | 差分対象の設定あり |

## CIパイプライン構成の理想形

```
PR opened
  ├─ [並列] lint + format check
  ├─ [並列] type check
  ├─ [並列] secret scan (gitleaks/TruffleHog)
  ├─ [並列] SAST (Semgrep/CodeQL)
  ├─ [順次] test → coverage report
  ├─ [順次] build → artifact
  └─ [条件] container scan (Dockerfile変更時)

merge to main
  ├─ 全テスト実行（flaky含む）
  ├─ SCA (Trivy/Snyk)
  └─ SBOM生成（リリース時）
```

### 重要原則

- **並列化**: 独立したチェックは並列実行（SAST + secrets + lint 同時）
- **差分スキャン**: 変更ファイルのみ対象で速度を維持（全体スキャンは定期実行）
- **Fail-fast**: critical/high severity のみブロック。info/low は通知のみ
- **PRコメント**: 検出結果をインラインコメントでPRに表示（別ダッシュボードは見られない）

## GitHub Actions 固有

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| actions のバージョンピン | `uses: actions/checkout@v4` ではなく SHA ピン `@abc123` | SHA or tag ピン |
| `GITHUB_TOKEN` の最小権限 | `permissions:` ブロックでスコープ制限 | permissions 明示 |
| `pull_request_target` の安全な使用 | `pull_request_target` で checkout する場合 head ref を使っていない | 安全な使用 |

## 判定基準

| スコア | 条件 |
|--------|------|
| A | test + lint + security scan + quality gate + カバレッジPR表示 + キャッシュ + 並列化 |
| B | test + lint/format がCIで実行 + PRブロック設定 |
| C | CI存在するがテストのみ、またはlint/securityが未統合 |
| F | CI未設定、またはCIがあるが実質的なチェックなし |
