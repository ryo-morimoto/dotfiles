---
title: "feat: Forgejo (Tailnet限定) を ryobox に導入"
type: feat
status: active
date: 2026-04-18
revised: 2026-04-19
---

# feat: Forgejo (Tailnet限定) を ryobox に導入

## Overview

個人開発のprimary forgeとして Forgejo を ryobox にセルフホストする。 ingress は Caddy + caddy-tailscale plugin で `git.<tailnet>.ts.net` 独立 node に TLS 終端し、 git 操作は HTTPS のみ。 GitHub は push mirror 先として retain し、 repo 作成時に Forgejo API から自動設定する helper を用意する。試験 project 量産を前提に手作業を最小化する。

## Problem Frame

- 個人プロジェクトを GitHub に集中するとアカウント閉鎖・ ToS 変更でロストする懸念
- 試験的 project を頻繁に立ち上げる運用 → repo 新設コストは最小にしたい
- Tailnet 内にすでに ryobox (常時稼働) と Caddy + agenix + Tailscale SSH という土台がある
- OpenSSH を無効化済みで Tailscale SSH 運用のため、 Forgejo 側 SSH も追加したくない
- 非対面の個人利用のため、単 user admin + 最小構成で十分

## Requirements Trace

- R1. Forgejo が ryobox 上で常駐し Tailnet 内の他端末からブラウザ / HTTPS clone でアクセスできる
- R2. `git clone https://...` で認証 (basic / PAT) 経由のみ。 SSH clone は閉じる
- R3. DB は PostgreSQL。 sqlite に後退させない
- R4. Caddy が Tailscale 発行証明書で `*.ts.net` hostname を自動化する (Cloudflare DNS-01 経路は使わない)
- R5. Forgejo DB + repo + LFS の自動ダンプが取れる
- R6. 公開 registration は閉じ、 admin account だけ初期作成できる
- R7. 既存 firewall (`tailscale0` のみ 80/443) を維持し、公開 port を増やさない
- R8. GitHub push mirror は repo 作成時に Forgejo API 経由で自動設定される (手作業 UI 操作不要)

## Scope Boundaries

- Forgejo Actions / runner 導入はしない
- Email 通知 (SMTP) 設定はしない
- Multi-user / external registration / OAuth / OIDC はしない
- Forgejo 側 SSH server は立てない
- 他 host への展開 (multi-host deployment) は考慮しない

### Deferred to Separate Tasks

- Forgejo Actions + nix-built runner: 別 plan
- 複数 admin / team 招待フロー: 別 plan
- backup の外部 (別 host / S3) 転送: 別 plan (現状は ryobox ローカルに dump)
- Tailnet 上の他 service の node 識別子追加 (例: `monitoring.<tailnet>.ts.net`): 本 plan では forgejo 用 `git` node のみ作る

## Context & Research

### Relevant Code and Patterns

- `hosts/ryobox/default.nix:97-105` — Caddy `withPlugins` に Cloudflare plugin が登録済。 `caddy-tailscale` を同じ list に追加するだけで拡張できる既存形
- `hosts/ryobox/default.nix:126-149` — agenix secrets パターン (`age.secrets.<name> = { file = ../../secrets/<name>.age; owner = ...; mode = "0400"; }`)
- `hosts/ryobox/default.nix:151` — `systemd.services.caddy.serviceConfig.EnvironmentFile` で secret を注入する既存例 (Tailscale auth key を同手法で入れる)
- `hosts/ryobox/default.nix:49-55` — `networking.firewall.interfaces.tailscale0.allowedTCPPorts = [80 443]` (外部 firewall 変更不要)
- `hosts/ryobox/default.nix:108-112` — Tailscale (`useRoutingFeatures = "client"`, `--ssh`)
- `secrets/secrets.nix` — ryobox 単一 host agenix recipient pattern
- `home/agents/` / `home/knowledge/` / `home/tmux/` — 責務ごとに file 分ける既存慣習 → `hosts/ryobox/forgejo.nix` を新設する根拠
- `packages/*.nix` — `callPackage` + `writeShellScriptBin` 系のユーティリティを localOverlay で配る既存 pattern

### Institutional Learnings

- `docs/solutions/` は本 repo に未設置
- CLAUDE.md `feedback_no_local_edit.md` — dotfiles 管理下のファイルは Nix 経由でしか変更しない。 Forgejo が書き換える設定 (app.ini) は stateDir 配下に任せ、 Nix 宣言は `services.forgejo.settings` に寄せる

### External References

- NixOS wiki: https://wiki.nixos.org/wiki/Forgejo — `services.forgejo` 基本 block、 SSH 無効化 (`DISABLE_SSH + START_SSH_SERVER=false`)、 postgres (`database.type = "postgres"` + `database.createDatabase = true`)
- caddy-tailscale: https://github.com/tailscale/caddy-tailscale — Caddy plugin。 module path `github.com/tailscale/caddy-tailscale`。 `bind tailscale/<node>` で node 識別子単位の listener、 `tls { get_certificate tailscale }` で Tailscale 発行 cert を自動取得
- Tailscale TLS: https://tailscale.com/kb/1153/enabling-https — Tailnet の HTTPS 機能は admin console で有効化 + `tailscale cert` 相当の権限付与が前提
- Forgejo API: `POST /api/v1/repos/{owner}/{repo}/push_mirrors` (body: `remote_address`, `remote_username`, `remote_password`, `interval`, `sync_on_commit`)、 `POST /api/v1/user/repos` で repo 作成
- NixOS option: `services.forgejo.dump.{enable, interval, type, backupDir}`

## Key Technical Decisions

- **Module 分割**: `hosts/ryobox/forgejo.nix` を新設し `imports` 経由で取り込む。消しやすい / 責務が明確。 `default.nix` 既存 290 行の見通しを保つ。 `home/` の subfolder 慣習と整合
- **DB**: PostgreSQL。 `services.postgresql.enable = true` を forgejo.nix 内で有効化し、 `database.createDatabase = true` で forgejo module に DB/role 作成を任せる。 unix socket のみ (TCP 非公開)
- **SSH 無効化**: `services.forgejo.settings.server.START_SSH_SERVER = false` + `DISABLE_SSH = true` を二重指定。 Tailscale SSH との干渉を防ぐ
- **TLS / Domain**: **Tailscale 発行証明書 + caddy-tailscale plugin 採用**。 `caddy.withPlugins` に `github.com/tailscale/caddy-tailscale` を追加し、 Caddy 内に独立した tailnet node 識別子 `git` を tsnet で作成。 FQDN は `git.<tailnet>.ts.net` (user の tailnet 名は実装時埋め込み)。 Tailscale auth key は agenix (`secrets/caddy-tailscale-authkey.age`) → Caddy EnvironmentFile 経由。外部 DNS 不要、 cert lifecycle は Caddy + Tailscale が完結。 Cloudflare DNS-01 経路は本 forgejo 用途では使わない (既存 Cloudflare secret は他用途のため残す)
- **Mirror 自動化**: **Forgejo API で repo 作成時に push_mirror を同時宣言する helper を packages/ に追加**。 `forgejo-new-repo <name>` 1 コマンドで (1) GitHub 側に空 repo 作成 (`gh repo create`)、 (2) Forgejo 側に repo 作成 (`POST /api/v1/user/repos` + agenix の Forgejo PAT)、 (3) push_mirror を宣言 (`POST /api/v1/repos/{owner}/{repo}/push_mirrors` + `gh auth token` の GitHub PAT)。 Forgejo admin token は agenix `secrets/forgejo-admin-token.age` で暗号化保管、 home の shell 起動時に env var に出す。 GitHub PAT は `gh auth token` 実行時取得 → secret 増やさない
- **Backup**: `services.forgejo.dump.enable = true` で日次 zip dump を `/var/lib/forgejo/dump` に出力。外部転送は deferred
- **Admin 作成**: NixOS 宣言ではなく初回 `forgejo admin user create` を手動。 "admin" 不可なので username は実装時 user 確認

## Alternative Approaches Considered

### TLS / Domain 候補

| 候補 | 長所 | 短所 | 判定 |
|---|---|---|---|
| A. Caddy + Cloudflare DNS-01 (初版採用) | 既存 plugin パイプライン流用 | tailnet IP が public DNS に可視 / 外部 domain 所有が前提 | ✗ |
| B. caddy-tailscale plugin + Tailscale 発行 cert (**採用**) | 外部 DNS 不要、 tailnet 完結、 cert lifecycle が Caddy 一本化、 node 識別子で service ごとに `<svc>.<tailnet>.ts.net` を払い出せる | tailscale auth key を agenix 化する 1 step 追加、 plugin の長期保守依存 | ✓ |
| C. Tailscale Serve (Caddy bypass) | 最小構成 | Caddy と並立 → ingress 二系統、将来の他 service 追加時に非一貫 | ✗ |
| D. Caddy internal CA (self-signed) | 完全オフライン | tailnet 全端末に root CA 配布が煩雑 | ✗ |
| E. HTTP only | 設定最小 | PAT / basic auth が平文 | ✗ |

**選択意図**: 試験 project 多数運用 → 将来 `<svc>.<tailnet>.ts.net` を量産する可能性が高い。 node 識別子という primitive が公式 plugin で得られるなら、一度の auth key 設定投資で将来展開が無料になる。 ingress を Caddy 一本化する原則も維持。

### Mirror 自動化候補

| 候補 | 長所 | 短所 | 判定 |
|---|---|---|---|
| A. Forgejo Web UI 手動設定 (初版採用) | 設定ゼロ、 PAT は Forgejo 内暗号化 | repo 毎に 2 分作業、忘却リスク | ✗ |
| B. Forgejo API + helper script (**採用**) | 1 コマンドで GitHub + Forgejo + mirror 宣言、再現可能、試験 project を即量産 | Forgejo admin token を agenix に 1 本追加、 helper の保守 | ✓ |
| C. post-receive git hook で直接 push | 標準 mirror 機能を迂回 | hook を repo 毎に仕込む、 Forgejo upgrade 時に整合性懸念 | ✗ |
| D. GitHub 側 pull mirror | Forgejo 負荷なし | GitHub は push mirror 方向の pull を一般提供していない | ✗ (不可) |
| E. 別 orchestrator (cron / renovate-like) | 柔軟 | overkill | ✗ |

**選択意図**: "試験的プロジェクト複数" が前提 → repo 新設頻度が上がる。 UI 手動の 2 分 × 月数回 が累積する運用負担 + 忘却で mirror が抜ける sitation を script 1 本で断つ。 GitHub PAT は `gh auth token` runtime 取得で secret 数増加を避ける。 Forgejo 側 token のみ agenix 1 本追加。

## Open Questions

### Resolved During Planning

- **SSH 経路**: HTTPS only (user 回答)
- **DB**: PostgreSQL (user 回答)
- **公開範囲**: Tailnet 限定 (user 回答)
- **module 分割**: `hosts/ryobox/forgejo.nix` 新設 (user 確認済み、消しやすさ優先)
- **TLS 方式**: caddy-tailscale plugin + Tailscale 発行 cert (user 回答 B)
- **Mirror**: Forgejo API + helper script (user 回答 B)

### Deferred to Implementation

- **Tailnet 名**: `<tailnet>.ts.net` の具体値 (Tailscale admin console で確認可)。 Unit 3 で user に直接確認して埋め込む
- **Admin username**: "admin" 以外の候補 (ryo / moriryo など)。 Unit 5 で user に直接確認
- **Tailnet HTTPS 有効化状態**: admin console で HTTPS 機能が既に ON かどうか。 OFF なら user が dashboard で ON にする前提 (NixOS 宣言外作業)。 Unit 3 verification で確認
- **LFS 使用量 / dump 保持期間**: 初期は無制限 / 7日保持で開始、運用後に調整
- **Forgejo admin token の発行方法**: 初回 admin 作成後 UI で個人 access token を発行 → agenix へ投入。 Unit 6 の runbook に記載

## Implementation Units

- [ ] **Unit 1: Forgejo module skeleton + PostgreSQL 有効化**

**Goal:** `hosts/ryobox/forgejo.nix` を新設し、 PostgreSQL サービスと Forgejo service の最小設定を有効化する (まだ外部公開も backup もしない)

**Requirements:** R3

**Dependencies:** なし

**Files:**
- Create: `hosts/ryobox/forgejo.nix`
- Modify: `hosts/ryobox/default.nix` (imports に `./forgejo.nix` 追加)

**Approach:**
- `services.postgresql.enable = true`
- `services.forgejo.enable = true`
- `services.forgejo.database = { type = "postgres"; createDatabase = true; }`
- `services.forgejo.settings.server` は最小 (`HTTP_PORT=3000`, `HTTP_ADDR="127.0.0.1"`)
- `services.forgejo.settings.service.DISABLE_REGISTRATION = true`

**Patterns to follow:**
- `home/knowledge/obsidian.nix` の単一責務 module 構成
- `hosts/ryobox/default.nix` の既存 `services = { ... }` ブロックは変更せず、新 module 内で宣言する

**Test scenarios:**
- Happy path: `sudo nixos-rebuild switch --flake .#ryobox` 成功 → `systemctl is-active postgresql forgejo` が active
- Happy path: `sudo -u postgres psql -l` に `forgejo` DB が存在
- Edge case: 再 rebuild でも `ensureDBOwnership` が冪等
- Test expectation: 自動 test なし — smoke は rebuild + `systemctl status` + `curl 127.0.0.1:3000` で代替

**Verification:**
- `nix flake check` 成功
- `sudo nixos-rebuild switch --flake .#ryobox` がエラーなく完了
- `curl -sS http://127.0.0.1:3000/` が Forgejo HTML
- `systemctl cat forgejo` に `DATABASE_TYPE=postgres` 相当が含まれる

- [ ] **Unit 2: SSH 無効化 + LFS + DOMAIN / ROOT_URL 確定**

**Goal:** Forgejo server 設定を本番値に確定する (SSH 完全無効化、 LFS 有効、 `git.<tailnet>.ts.net` を DOMAIN に)

**Requirements:** R2, R6

**Dependencies:** Unit 1

**Files:**
- Modify: `hosts/ryobox/forgejo.nix`

**Approach:**
- `services.forgejo.settings.server`:
  - `DOMAIN = "git.<tailnet>.ts.net"` (tailnet 名は実装時確認)
  - `ROOT_URL = "https://git.<tailnet>.ts.net/"`
  - `HTTP_ADDR = "127.0.0.1"`, `HTTP_PORT = 3000`
  - `DISABLE_SSH = true`, `START_SSH_SERVER = false`
- `services.forgejo.lfs.enable = true`
- `services.forgejo.settings.repository.DEFAULT_BRANCH = "main"`

**Patterns to follow:**
- NixOS wiki Forgejo の settings 例

**Test scenarios:**
- Happy path: `curl -sS http://127.0.0.1:3000/api/v1/version` が JSON
- Happy path: UI で test repo 作成 → clone URL が `https://git.<tailnet>.ts.net/...` を表示、 `ssh://` 無し
- Error path: `ss -tlnp` に Forgejo SSH port bind 無し
- Edge case: `DISABLE_SSH=true` 単独では host key 生成を抑止しきれない可能性 → `START_SSH_SERVER=false` を併設

**Verification:**
- `ss -tlnp | grep 3000` に Forgejo のみ、 `ss -tlnp | grep 22` に Forgejo 無し
- Site Admin UI の Configuration で SSH が disabled 表示

- [ ] **Unit 3: caddy-tailscale plugin + `git` node 識別子で TLS 終端**

**Goal:** Caddy に caddy-tailscale plugin を追加し、独立 tailnet node `git` を作って `git.<tailnet>.ts.net` で TLS 終端、 Forgejo に reverse proxy する

**Requirements:** R1, R4, R7

**Dependencies:** Unit 2

**Files:**
- Create: `secrets/caddy-tailscale-authkey.age`
- Modify: `secrets/secrets.nix` (recipient 追加)
- Modify: `hosts/ryobox/default.nix`:
  - `services.caddy.package` の `withPlugins` list に `github.com/tailscale/caddy-tailscale` を追加 (`hash` は build 失敗メッセージから埋める)
  - `services.caddy.virtualHosts."git.<tailnet>.ts.net"` 追加
  - Caddy global block (`services.caddy.globalConfig` 相当) に tailscale authkey 設定
  - `age.secrets.caddy-tailscale-authkey = { file = ../../secrets/caddy-tailscale-authkey.age; owner = "caddy"; mode = "0400"; }`
  - `systemd.services.caddy.serviceConfig.EnvironmentFile` を既存 Cloudflare secret と両方読むよう list 化

**Approach:**
- Tailscale admin console で HTTPS 機能を ON (NixOS 宣言外作業)
- Tailscale admin console で reusable auth key を発行、 `agenix -e caddy-tailscale-authkey.age` で暗号化
- Caddy global config 例:
  ```
  {
    tailscale {
      auth_key {env.TS_AUTHKEY}
      ephemeral false
      hostname git
    }
  }
  ```
- vhost:
  ```
  git.<tailnet>.ts.net {
    bind tailscale/git
    tls {
      get_certificate tailscale
    }
    reverse_proxy 127.0.0.1:3000
    request_body {
      max_size 512MB
    }
  }
  ```
- EnvironmentFile で `TS_AUTHKEY=<decrypted>` を caddy サービスに渡す
- firewall: 追加変更なし (caddy-tailscale は tsnet で独立に tailnet 接続するため、 host の 443 open は不要)

**Patterns to follow:**
- `hosts/ryobox/default.nix:97-105` の `withPlugins` list 追記
- `hosts/ryobox/default.nix:151` の EnvironmentFile pattern を list 化で拡張

**Test scenarios:**
- Happy path: rebuild 後 Tailscale admin console の Machines に `git` node が Caddy 経由で登録される
- Happy path: tailnet 上の別 host から `curl -sS https://git.<tailnet>.ts.net/` が 200 + Forgejo HTML
- Happy path: `curl -vv` で Tailscale が発行した LE 証明書 (`subject CN=git.<tailnet>.ts.net`) が提示される
- Error path: tailnet 外から `git.<tailnet>.ts.net` は DNS 解決しない / 到達不能
- Integration: UI から 100MB LFS push が `413` にならず成功
- Edge case: Caddy 再起動後に `git` node が短時間で再登録される (ephemeral=false)

**Verification:**
- Caddy journal に Tailscale node 登録と cert 取得成功の log
- `nix flake check` 成功、 rebuild 成功
- tailnet 外端末から到達不能を確認
- admin console の Machines に `git` が active

- [ ] **Unit 4: Forgejo 自動 dump 有効化**

**Goal:** `services.forgejo.dump` で DB + repo + LFS の日次 dump を取得する

**Requirements:** R5

**Dependencies:** Unit 1

**Files:**
- Modify: `hosts/ryobox/forgejo.nix`

**Approach:**
- `services.forgejo.dump = { enable = true; interval = "daily"; type = "zip"; backupDir = "/var/lib/forgejo/dump"; }`
- 外部転送は deferred

**Patterns to follow:**
- `hosts/ryobox/default.nix:250-255` の `nix.gc` と同じ感覚の schedule 宣言

**Test scenarios:**
- Happy path: `systemctl start forgejo-dump.service` が exit 0 で `/var/lib/forgejo/dump/forgejo-dump-*.zip` を生成
- Happy path: `systemctl list-timers | grep forgejo` で daily timer 登録
- Edge case: dump 中も Forgejo は online
- Error path: backupDir 空き不足 → journal にエラー (自動 alert 無し)

**Verification:**
- 最新 zip が存在、 unzip で `forgejo-db.sql` と repo tree が含まれる

- [ ] **Unit 5: Admin bootstrap runbook**

**Goal:** 初回 admin user 作成 + Forgejo user token 発行手順を documented にし、 Unit 6 の helper を動かす前提を整える

**Requirements:** R6

**Dependencies:** Unit 3

**Files:**
- Create: `docs/runbooks/forgejo-setup.md`

**Approach:** runbook に以下を記載:
1. 初回 admin: `sudo -u forgejo forgejo admin user create --admin --username <name> --email <email> --random-password` → password を控える ("admin" 不可)
2. ログイン後 password 変更 + TOTP 有効化
3. UI → User Settings → Applications → Generate New Token (scope: `write:repository`, `read:user`) → Forgejo admin token を取得
4. `agenix -e secrets/forgejo-admin-token.age` で token を暗号化保管 (Unit 6 で宣言)
5. rebuild 後に Unit 6 の `forgejo-new-repo` helper が token を参照可能

**Test scenarios:**
- Test expectation: none — docs only。手順の再現性は人間 review

**Verification:**
- `docs/runbooks/forgejo-setup.md` 存在、手順に沿って admin + token 発行が成功

- [ ] **Unit 6: `forgejo-new-repo` helper + Forgejo admin token agenix**

**Goal:** `forgejo-new-repo <name>` 1 コマンドで GitHub repo 作成 + Forgejo repo 作成 + push mirror 宣言までを自動化する

**Requirements:** R8

**Dependencies:** Unit 5

**Files:**
- Create: `packages/forgejo-new-repo.nix` (`writeShellScriptBin`)
- Modify: `flake.nix` (localOverlay に `forgejo-new-repo = final.callPackage ./packages/forgejo-new-repo.nix { };`)
- Modify: `home/default.nix` (`home.packages` に追加)
- Create: `secrets/forgejo-admin-token.age`
- Modify: `secrets/secrets.nix`
- Modify: `hosts/ryobox/default.nix` (`age.secrets.forgejo-admin-token = { ... owner = username; mode = "0400"; }`)
- Modify: `home/default.nix` (zsh env で `[[ -r /run/agenix/forgejo-admin-token ]] && export FORGEJO_TOKEN="$(cat /run/agenix/forgejo-admin-token)"`)

**Approach:**
- Script 引数: `<repo-name>` (必須)、 `--private|--public` (default private)
- 依存: `curl`, `jq`, `gh` (既に system に存在)
- 処理順:
  1. `gh repo create <owner>/<repo-name> --<visibility>` で GitHub 空 repo 作成 (既存 `gh auth` を活用)
  2. `curl -X POST https://git.<tailnet>.ts.net/api/v1/user/repos -H "Authorization: token $FORGEJO_TOKEN" -d '{"name":"<repo>","private":true,"auto_init":false}'` で Forgejo 側作成
  3. `gh auth token` で GitHub PAT 取得 → `curl -X POST https://git.<tailnet>.ts.net/api/v1/repos/<owner>/<repo>/push_mirrors -d '{"remote_address":"https://github.com/<owner>/<repo>.git","remote_username":"<gh-user>","remote_password":"<gh-pat>","interval":"8h0m0s","sync_on_commit":true}'` で mirror 宣言
- エラー処理: 各 step の HTTP 200/201 確認、失敗時は中断 + rollback (Forgejo repo 削除 API 呼び出し)
- `FORGEJO_TOKEN` 未設定時は明示エラーで停止

**Patterns to follow:**
- `packages/showboat.nix` など既存 `writeShellScriptBin` pattern
- `home/default.nix:430-432` の agenix secret → env var pattern

**Test scenarios:**
- Happy path: `forgejo-new-repo test-001` → GitHub / Forgejo 両方に repo 作成され Forgejo Settings に push mirror entry 存在
- Happy path: 初回 commit を Forgejo に push → 8h 以内に GitHub 側に反映 (手動 trigger: Forgejo UI の "Synchronize Now" で即時確認)
- Error path: GitHub repo が既に存在する名前 → `gh repo create` の error を surface して Forgejo 側は作成しない
- Error path: `FORGEJO_TOKEN` 未設定 → script が即エラー終了、 GitHub repo も作らない (pre-check)
- Error path: Forgejo API が 401/403 → rollback で GitHub repo 削除案内 (削除は手動、 script は message 出すのみ)
- Edge case: repo 名に `-` や数字が混在しても URL escape される
- Integration: script 完了後、 `git clone https://git.<tailnet>.ts.net/<owner>/<repo>.git` が動作

**Verification:**
- `forgejo-new-repo test-001` が exit 0
- GitHub / Forgejo 両方に repo 存在
- Forgejo Web UI → Settings → Mirror Settings に push mirror 1 件登録、 `sync_on_commit=true`

## System-Wide Impact

- **Interaction graph:** Caddy (tsnet node `git`) → Forgejo (127.0.0.1:3000) → PostgreSQL (unix socket)。 forgejo-new-repo helper → `gh` (GitHub API) + Forgejo API。既存 niri / fcitx5 / Tailscale daemon は影響なし
- **Error propagation:** PostgreSQL 停止 → Forgejo 503。 Caddy 健常なら error page。 Caddy 停止 → `git.<tailnet>.ts.net` 到達不能。 Tailscale 障害 → tailnet 全体不達 (既知の single point)
- **State lifecycle risks:**
  - `/var/lib/forgejo` (stateDir): postgres DB (論理)、 repo tree、 LFS blob、 `app.ini`
  - Caddy tsnet node state: `/var/lib/caddy/...` 下に Tailscale node 鍵が保存される。 rebuild で消えない限り node identity は維持。 backup 対象に追加推奨 (Unit 4 の dump 範囲外なので将来の backup plan で扱う)
  - Forgejo admin token (agenix): 漏洩時は UI で revoke、 `agenix -e` で再発行
- **API surface parity:** GitHub との API 互換は不要 (個人利用)。 forgejo-new-repo helper は `gh` 依存 → GitHub CLI 認証が前提
- **Integration coverage:** caddy-tailscale plugin の動作は upstream 依存。 plugin breaking change 時は rebuild 失敗で surface する
- **Unchanged invariants:**
  - `firewall.interfaces.tailscale0.allowedTCPPorts = [80 443]` 変更無し (caddy-tailscale は tsnet で独立接続、 host の port は使わない)
  - OpenSSH 無効化維持
  - Tailscale SSH 維持
  - 既存 Cloudflare plugin 残存 (他用途のため)
  - `system.autoUpgrade` の daily rebuild は forgejo / caddy を再起動するが data loss 無し

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| caddy-tailscale plugin が nixpkgs の `caddy.withPlugins` で build 失敗 | 初回 build で `hash` mismatch error から正しい hash を拾う (既存 Cloudflare plugin と同手順)。 plugin が非対応なら fallback として `tailscale cert` + systemd timer に切替え可能 |
| Tailscale auth key の rotation 忘れ (reusable key が revoke された場合) | key 発行時に有効期限 90日。 90日前 reminder を Linear / calendar に入れる (agenix 再暗号化) |
| `gh auth token` の token 期限切れで mirror が stuck | Forgejo UI で mirror 編集 → PAT 更新の手動運用 (頻度は低い) |
| Forgejo admin token 漏洩 | 範囲を `write:repository`, `read:user` に絞る。 UI で revoke 即時化 |
| caddy-tailscale breaking change で rebuild 失敗 → git が落ちる | rollback は `nixos-rebuild --rollback`。 flake input 固定で不意の upgrade を防ぐ (必要なら flake.lock 固定) |
| Tailscale HTTPS が admin console で無効なまま rebuild → cert 取得失敗 | Unit 3 の pre-check に「admin console で HTTPS 有効化」を記載 |
| forgejo-new-repo が途中失敗して GitHub 側に orphan repo 残存 | script 内で失敗時 `gh repo delete` を案内 (確認 prompt 付き)。 自動削除は destructive なので手動運用 |
| system.autoUpgrade の 05:00 rebuild で forgejo / caddy 再起動 | 個人用のため許容。 active session は稀 |

## Documentation / Operational Notes

- `docs/runbooks/forgejo-setup.md` (Unit 5) に初回 admin + token 発行 + Tailscale HTTPS 有効化 + `forgejo-new-repo` 使用例
- CLAUDE.md / AGENTS.md への追記は不要 (dotfiles 管理者=user 単独)
- 将来 tailnet 上で他 service を立てる際は、 本 plan の `git` node パターンを踏襲して `<svc>.<tailnet>.ts.net` を追加する (Deferred to Separate Tasks)

## Sources & References

- NixOS wiki: https://wiki.nixos.org/wiki/Forgejo
- NixOS options: https://search.nixos.org/options?channel=unstable&query=services.forgejo
- caddy-tailscale: https://github.com/tailscale/caddy-tailscale
- Tailscale HTTPS: https://tailscale.com/kb/1153/enabling-https
- Forgejo API: Gitea-compatible swagger (`/api/v1/repos/{owner}/{repo}/push_mirrors`, `/api/v1/user/repos`)
- Existing code: `hosts/ryobox/default.nix:97-149`, `secrets/secrets.nix`, `flake.nix:28-31` (agenix), `packages/showboat.nix` (writeShellScriptBin pattern reference)
- Related user prefs (memory): `feedback_no_local_edit.md`, `feedback_dotfiles_skills_placement.md`
