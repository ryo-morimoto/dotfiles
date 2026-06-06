# caddy-tailscale OAuth 切替 ハンドオフ

## 目的

`feat/plane-tailnet` branch の Unit 4 (caddy-tailscale plugin + 両 vhost) を完了させる。
元プラン: `2026-04-19-001-feat-plane-tailnet-deployment-plan.md`

前セッションで直接 auth key 方式が不安定だったため OAuth client 方式へ切替中。
ACL 周りの理解不足があり、別セッションで再開する。

## 前提と状態

- Worktree: `/home/ryo-morimoto/ghq/github.com/ryo-morimoto/dotfiles-plane/`
- Branch: `feat/plane-tailnet`
- Tailnet: `tail9f641.ts.net`
- Unit 1, 2 (Plane) は完了。Plane は `https://plane.tail9f641.ts.net` 経由で稼働確認済み (ただし Caddy 切替前は tailscale SSH + port-forward 前提の検証だった可能性あり — 再検証項目)
- Forgejo (Unit 3) は `git.tail9f641.ts.net` 想定で配線済み、Caddy の tsnet ノード `git` が必要

## 今回セッションで行った変更 (コミット未)

- `hosts/ryobox/default.nix`:
  - `globalConfig` の default ブロックに `tags tag:caddy` を追加
  - agenix secret 名を `caddy-tailscale-authkey` → `caddy-tailscale-oauth` にリネーム
  - `EnvironmentFile` パス参照も追従
- `secrets/secrets.nix`: `caddy-tailscale-authkey.age` → `caddy-tailscale-oauth.age`
- `secrets/caddy-tailscale-authkey.age` を `caddy-tailscale-oauth.age` へ `git mv`
  - 中身は旧 auth key のまま。OAuth client secret で再暗号化が必要

## caddy-tailscale README 由来の確定事項

- OAuth client secret は `auth_key` ディレクティブと同じ箇所に入れる (別ディレクティブではない)
- OAuth で auth key を生成する場合、登録時と同じ tag を caddy 設定側で `tags` に明示する必要あり
- query params で挙動制御: `?preauthorized=true&ephemeral=false` (永続ノード想定)
- `ephemeral` ディレクティブは OAuth トークンには効かない

## ACL 理解不足 (次セッションで解消すべき点)

1. **tagOwners の最小権限**: `"tag:caddy": ["autogroup:admin"]` でよいか、`autogroup:member` や特定 user/group に絞るべきか
2. **tag 階層**: 既存の `tag:plane` / `tag:forgejo` などがあるか? 重複/衝突の有無
3. **ACL rules への影響**: `tag:caddy` を付けたノードから `127.0.0.1:3000` (forgejo) / `127.0.0.1:8090` (plane) への access を ACL で明示許可する必要があるか (tailnet 内同一ホスト localhost なら通常不要だが要確認)
4. **device approval**: tailnet が device approval を要求している場合、OAuth 生成ノードも承認が必要か
5. **ephemeral vs non-ephemeral の運用差**: rebuild ごとにノードが再作成されるか、state_dir で永続するか (state_dir = `/var/lib/caddy/tsnet` を設定済みなので永続するはず、要検証)
6. **既存ノードとの衝突**: 同じ hostname (`git`, `plane`) のノードが残っている場合の挙動

## 次セッションの作業手順 (ACL 理解後)

### admin console 側

1. ACL 編集 (Access Controls):
   ```json
   "tagOwners": {
     "tag:caddy": ["autogroup:admin"]
   }
   ```
   (↑は最小権限の判断後に確定)
2. OAuth client 発行 (Settings → OAuth clients):
   - Scopes: `auth_keys` Write
   - Tags: `tag:caddy`
   - client secret (`tskey-client-xxx...`) を取得

### ryobox 側 (コピペ)

```sh
RECIPIENT=$(sudo cat /etc/ssh/ssh_host_ed25519_key.pub)
cd ~/ghq/github.com/ryo-morimoto/dotfiles-plane
echo 'TS_AUTHKEY=tskey-client-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx?preauthorized=true&ephemeral=false' \
  | age -a -r "$RECIPIENT" > secrets/caddy-tailscale-oauth.age

git add secrets/caddy-tailscale-oauth.age secrets/secrets.nix hosts/ryobox/default.nix
sudo nixos-rebuild switch --flake .#ryobox
```

### 検証

```sh
systemctl is-active caddy
journalctl -u caddy -n 40 --no-pager
tailscale status | grep -E 'git|plane'
curl -sI https://git.tail9f641.ts.net/
curl -sI https://plane.tail9f641.ts.net/
```

## 既知の落とし穴 (前セッションで踏んだもの)

- `agenix` CLI は未導入。暗号化は `age -a -r "<ssh-pub>" > file.age` のみ
- `openssl` 未導入。random は `head -c 32 /dev/urandom | base64`
- `nix flake check` は git 管理下ファイルしか見ない → 新規 `.age` は先に `git add`
- `.env` 内 password に `/` が含まれると `DATABASE_URL` 解析が壊れる (Plane 側で解消済み、jq @uri でエンコード)
- Caddy の `{$VAR:default}` は VAR が未設定のときのみ fallback、空文字設定では fallback しない
- caddy-tailscale plugin の Go version tag は pseudo-version 必須: `v0.0.0-20260106222316-bb080c4414ac`
- zsh では `read -p` 不可、`read -rs "k?prompt: "` 形式

## 関連ファイル

- `hosts/ryobox/default.nix` (caddy 節、agenix 節、systemd.services.caddy)
- `hosts/ryobox/plane.nix` (参考、変更不要)
- `hosts/ryobox/forgejo.nix` (参考、変更不要)
- `secrets/secrets.nix`
- `secrets/caddy-tailscale-oauth.age` (中身が旧 authkey のままなので再暗号化必須)

## Follow-up (Unit 4 完了後)

- 元プラン `2026-04-19-001-feat-plane-tailnet-deployment-plan.md` の記述が oci-containers ベースのまま → fetchurl + systemd の実装に合わせて更新
- Unit 5 (Linear→Plane migration + MCP swap)
- Unit 6 (backup)
