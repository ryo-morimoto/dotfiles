# Portless Tailnet ingress runbook

## 構成

- 公開 URL: `https://<name>.p.ryobox.xyz`
- Caddy: ryobox の Tailscale IPv4/IPv6 の TCP 443
- Portless: `127.0.0.1:443` と `[::1]:443`
- 外向き TLS: Caddy + Cloudflare DNS-01
- Caddy から Portless: pin した自己署名 `*.p.ryobox.xyz` 証明書
- 認可対象: `ryo.morimoto.dev@gmail.com`
- Portless state: `/var/lib/portless`

Portless は非 root で動作し、systemd から `CAP_NET_BIND_SERVICE` だけを受け取る。`PORTLESS_ASSUME_BIND_CAPABILITY=1` は system service にだけ設定する。

worktree 内では `PORTLESS_FLAT_WORKTREE=1` により、URL を `https://<worktree>-<name>.p.ryobox.xyz` の 1 ラベル形式にする。これにより `*.p.ryobox.xyz` の wildcard DNS/TLS の範囲を外れない。

## deploy 前確認

現在の generation を store path で記録する。

```sh
readlink -f /run/current-system
nixos-rebuild list-generations
```

既存の socket と Tailscale Serve を記録する。

```sh
ss -ltnp | rg ':(80|443|1355|8443|8444)\b'
tailscale serve status --json | jq .
ps -eo pid,user,args | rg '[p]ortless'
```

旧 Devbox Portless v0.12.0、TCP 1355、Tailscale Serve :8444 は 2026-08-04 に廃止済みである。これらが存在する場合は意図しない旧構成の再導入として扱い、deploy を止めて除去する。

DNS は Cloudflare proxy を使わない。次を確認する。

```sh
dig +short test.p.ryobox.xyz A
dig +short test.p.ryobox.xyz AAAA
```

A record は `100.116.123.65` を指す。IPv6 を利用する場合は AAAA record を `fd7a:115c:a1e0::a736:7b41` に設定する。Tailscale ACL では既存の ryobox:443 の principal を広げない。

## build

```sh
nixfmt nix-config/flake.nix \
  nix-config/home/default.nix \
  nix-config/hosts/ryobox/default.nix \
  nix-config/hosts/ryobox/portless.nix \
  nix-config/packages/portless/default.nix \
  nix-config/secrets/secrets.nix
nix flake check ./nix-config
nix build ./nix-config#portless
nix build ./nix-config#nixosConfigurations.ryobox.config.system.build.toplevel
```

未 commit の新規ファイルを含めて検証するときだけ、`./nix-config` の代わりに `path:./nix-config` を使う。

## deploy

一度に remote auto-upgrade へ任せず、ryobox 上で generation を明示して switch する。

```sh
sudo nixos-rebuild switch --flake ./nix-config#ryobox
```

切替直後に確認する。

```sh
systemctl --no-pager --full status tailscale-address-ready.service caddy.service portless.service
journalctl -u portless.service -u caddy.service -b --no-pager
ss -ltnp | rg ':(80|443|1355|8443|8444)\b'
portless_pid="$(systemctl show -p MainPID --value portless.service)"
rg '^Cap(Amb|Bnd|Eff):' "/proc/$portless_pid/status"
```

期待値:

- Caddy は `100.116.123.65:443` と Tailscale IPv6 の 443 にだけ bind する。
- Portless は loopback の 443 にだけ bind する。
- Tailscale IP や外部 interface に TCP 80 listener と firewall 許可は存在しない。Portless の loopback:80 redirect は許容する。
- Portless process は `ryo-morimoto` で、ambient capability は `cap_net_bind_service` だけである。
- Portless の journal に sudo prompt がない。

## route と疎通確認

新しい login shell で、Portless の環境変数と binary を確認する。

```sh
command -v portless
portless --version
env | rg '^PORTLESS_(FLAT_WORKTREE|HTTPS|PORT|STATE_DIR|SYNC_HOSTS|TLD)='
```

test route を起動する。

```sh
portless smoke-test sh -c 'exec python3 -m http.server "$PORT" --bind "$HOST"'
```

許可済み tailnet 端末から確認する。

```sh
curl --fail-with-body --show-error https://smoke-test.p.ryobox.xyz/
```

加えて次を確認する。

- 未許可 user は 403 になる。
- tailnet 外から到達しない。
- `nested.smoke-test.p.ryobox.xyz` は利用できない。
- `systemctl stop portless` 後、Portless wildcard だけが 502 となり、既存 Caddy vhost は正常である。
- `systemctl restart tailscaled caddy portless` 後に復旧する。

## Tailscale Serve の扱い

`tailscale-serve-reset.service` は deploy 時に mutable な Serve 設定を消す。成功後に `agent-canvas-tailscale-serve.service` を起動し、宣言済みの Agent Canvas :8443 だけを復元する。

旧 Portless `--tailscale` が作っていた :8444 は廃止済みであり、復元しない。再び現れた場合は mutable な旧 runtime state として削除する。

## 証明書更新

現在の内部証明書:

- SAN: `DNS:*.p.ryobox.xyz`
- SHA-256 fingerprint: `B5:9F:CA:F6:24:99:5D:92:32:34:3E:99:03:20:40:8B:48:D2:1D:4C:DB:85:FE:41:AD:5A:F2:11:88:65:62:9C`
- expires: 2027-09-05 07:25:51 UTC

更新時は、同じ生成処理から得た公開証明書と秘密鍵を必ず pair で置き換える。

1. SAN、basic constraints、serverAuth EKU を指定して新しい自己署名 leaf を生成する。
2. 秘密鍵を平文で repo や Nix store に置かず、ryobox の SSH recipient へ age 暗号化する。
3. `nix-config/certs/portless-wildcard.crt` と `nix-config/secrets/portless-tls-key.age` を同じ変更で更新する。
4. `openssl x509 -checkhost`、age 復号後の公開鍵一致、Caddy config validation を確認する。
5. Caddy と Portless を同じ generation で再起動する。

## rollback

Portless と旧 Caddy は同じ wildcard socket を共有できないため、次の順序を守る。

```sh
sudo systemctl stop portless.service
sudo /nix/store/<recorded-nixos-system>/bin/switch-to-configuration switch
```

旧 Devbox Portless process、TCP 1355、Tailscale Serve :8444 は rollback 時も復元しない。単純な `nixos-rebuild --rollback` は、途中で別 generation が作られていると意図しない世代へ戻るため使わない。
