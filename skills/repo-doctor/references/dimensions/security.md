# 次元5: セキュリティ

脆弱性をコードがプロダクションに到達する前に検出する。

## 検出チェック

### 必須項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| Secret 検知ツールが導入されている | `gitleaks.toml`, `.gitleaksignore`, TruffleHog設定, CI workflow内の参照 | pre-commit or CIで実行 |
| 依存脆弱性スキャン（SCA）が導入されている | Dependabot (`dependabot.yml`), Renovate (`renovate.json`), Trivy, Snyk の設定/CI参照 | 設定あり |
| `.env` / credentials がgitignoreされている | `.gitignore` 内に `.env`, `*.pem`, `*.key`, `credentials*` 等 | パターンあり |

### 推奨項目

| チェック | 検出方法 | 充足条件 |
|----------|----------|----------|
| SAST がCIで実行 | Semgrep, CodeQL, SonarQube の CI workflow 参照 | 実行設定あり |
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
| **Renovate** | Dependabotより柔軟。グルーピング、automerge、カスタムルール |
| **Snyk** | 商用。fix PR自動生成、ランタイム脆弱性も検出 |

### SAST

| ツール | 特徴 |
|--------|------|
| **Semgrep** | 言語横断カスタムルール。コミュニティレジストリ。高速 |
| **CodeQL** | GitHub native。プロシージャ間解析。OSSは無料 |
| **SonarQube** | 25+ quality model。Quality Gateでブロック |

## OWASP CI/CD Security Cheat Sheet の要点

- PRレビューをバイパス不可に設定
- 依存バージョンをピン+ハッシュ検証
- Secretsはハードコードせず Vault/Secrets Manager 使用
- 最小権限原則（deny by default）
- プロダクションデプロイ前に手動承認

## 判定基準

| スコア | 条件 |
|--------|------|
| A | Secret検知(pre-commit+CI) + SCA + SAST + SECURITY.md + SBOM(該当時) |
| B | Secret検知(pre-commit or CI) + SCA + .gitignoreでcredentials除外 |
| C | SCAのみ（Dependabot等）、またはSecret検知のみ |
| F | セキュリティスキャン未設定 |
