# 次元5: セキュリティ

脆弱性をコードがプロダクションに到達する前に検出する。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Secret 検知ツールが導入され、local 実行できる | `gitleaks.toml`, `.gitleaksignore`, TruffleHog設定, `just` / hook / package scripts 内の参照 | local 実行パスあり |
| 依存脆弱性スキャン（SCA）が導入されている | Dependabot (`dependabot.yml`), Renovate (`renovate.json`), Trivy, Snyk の設定/CI参照 | 設定あり |
| 対応 package manager に maturity gate がある | `pnpm-workspace.yaml`, `.npmrc`, `bunfig.toml` 等に `minimumReleaseAge` 相当の設定 | 対応時は 7 日以上を設定 |
| `.env` / credentials がgitignoreされている | `.gitignore` 内に `.env`, `*.pem`, `*.key`, `credentials*` 等 | パターンあり |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| SAST がlocal でも実行可能 | `semgrep`, `codeql`, `sonar-scanner` 等を `just` / script / documented command から呼べる | local 実行パスあり |
| SAST がCIで再確認される | Semgrep（既定）, CodeQL, SonarQube の CI workflow 参照 | 実行設定あり |
| `SECURITY.md` が存在 | ファイル存在チェック | 存在し脆弱性報告手順が記載 |
| コンテナスキャン（コンテナ使用時） | Trivy, Grype の CI 参照 | Dockerfile存在時に設定あり |
| IaC スキャン（IaC使用時） | Checkov, tfsec, trivy config の CI 参照 | terraform/等存在時に設定あり |
| SBOM 生成（OSSまたはプロダクション） | Syft, GitHub SBOM export の参照 | リリースワークフローに存在 |
| 署名付きコミット | `.gitconfig` or リポジトリ設定で GPG/SSH 署名 | 設定あり |

## ツール

### Secret 検知

| ツール | 用途 | 特徴 |
|--------|------|------|
| **Gitleaks** | pre-commit + CI | 高速、150+パターン、TOML設定。pre-commitの第一選択 |
| **TruffleHog** | CI（深い検査） | 検出したsecretが有効かを検証。S3, Docker image, Slack も走査可 |

**推奨戦略:** Gitleaks(pre-commit、速度) + TruffleHog(CI、深度) の二段構え

### 依存スキャン（SCA）

| ツール | 特徴 |
|--------|------|
| **Trivy** | OS packages, 言語依存, コンテナイメージ, IaC, SBOM — オールインワン |
| **Dependabot** | GitHub native。自動PR生成。設定が最も簡単 |
| **Renovate** | Dependabotより柔軟。グルーピング、automerge、`minimumReleaseAge` などの更新ポリシーを細かく制御 |
| **Snyk** | 商用。fix PR自動生成、ランタイム脆弱性も検出 |

### SAST

| ツール | 特徴 |
|--------|------|
| **Semgrep** | Repo Doctor の既定推奨。言語横断カスタムルール。コミュニティレジストリ。高速 |
| **CodeQL** | GitHub native。プロシージャ間解析。OSSは無料 |
| **SonarQube** | 25+ quality model。Quality Gateでブロック |

**推奨戦略:** `Semgrep` をベースラインSASTとし、まず local で回せる形を作る。GitHub native の深い解析が必要な場合に `CodeQL` を CI 側へ追加する。

## OWASP CI/CD Security Cheat Sheet の要点

- PRレビューをバイパス不可に設定
- 依存バージョンをピン+ハッシュ検証
- Secretsはハードコードせず Vault/Secrets Manager 使用
- 最小権限原則（deny by default）
- プロダクションデプロイ前に手動承認

## 判定基準

| スコア | 条件 |
|--------|------|
| A | Secret検知(local+CI) + SCA + package manager の maturity gate + SAST(local+CI) + SECURITY.md + SBOM(該当時) |
| B | Secret検知(local) + SCA + package manager の maturity gate（対応時） + .gitignoreでcredentials除外 |
| C | セキュリティチェックはあるが local 実行パスが弱い、または SCA のみ |
| F | セキュリティスキャン未設定 |
