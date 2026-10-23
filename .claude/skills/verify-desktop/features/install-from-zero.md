# ゼロからの再現

空のディスクから、宣言だけで同じ作業面を1時間以内に再現できる。消去するのは宣言した by-id のディスクだけで、宣言と違うディスクがつながっていれば、消去の前に止まる。

## Sub-features

- `refuse-wrong-disk`: 宣言と違うシリアル番号・容量のディスクでは、`wipe.py` が消去の前に止まる。
- `refuse-missing-by-id`: 宣言した by-id が無ければ止まる。
- `install-time`: ISO の起動から、`dv doctor` が fail を出さなくなるまでの時間が1時間以内 (FLX-3)。
- `post-install-launch`: 再現した環境で `dv launch`、`dv doctor`、`dv drive workspace` が通る。

## How to get to it (user POV)

- Arch の ISO で起動し (ADR-0007 により Secure Boot は無効)、dotfiles を取得して `install/bootstrap.sh` を実行する。
- 途中で、消去するディスクの by-id を入力して確認する。
- 初回起動でログインし、age の秘密鍵をパスワードマネージャから戻す。

## Driving it with dv

Preconditions:

- 段階5で `install/` (`disks.toml`、`wipe.py`、`bootstrap.sh`) ができている。D-V4 (`verify/run.sh`) が通っている。
- 代わりの環境: KVM の使える Linux で、QEMU の VM に仮想ディスクを2台付ける。シリアル番号は QEMU の `-drive ...,serial=` で決める。このセッションの作業場所には KVM が無く、まだ動かしていない。

Steps:

- **違うディスクで止まる (VM)。** `disks.toml` のシリアル番号と違う値を付けたディスクで、`bootstrap.sh` を実行する。`wipe.py` が「シリアル番号か容量が宣言と違う」で止まり、ディスクの先頭が変わっていないことを確かめる (`dd if=<disk> bs=1M count=1 | sha256sum` を前後で比べる)。
- **by-id が無いと止まる (VM)。** `disks.toml` の by-id を存在しない名前にして、止まることを確かめる。
- **再現の時間 (VM、その後に実機)。** `date -u +%FT%TZ` を記録して `bootstrap.sh` を実行する。初回起動でログインし、`dv doctor` が fail を出さなくなった時刻を記録する。差が60分以内なら pass。モデルの取得の時間は含めない (REL-4 の対象外で、再取得できる)。
- **再現した環境で動かす。** `dv launch`、`dv doctor`、`dv drive workspace` を実行する。

## Gotchas

- VM では NVIDIA の GPU が無いので、`dv doctor` の `nvidia` と、`workspace` の画面の check は fail になる。VM での時間は、それらを除いた手順の時間として記録する。実機の時間は、年1回か手段を替えるときに測る (6章)。
- VM の仮想ディスクは `/dev/disk/by-id/` に、`virtio-<serial>` か `scsi-...` の名前で出る。名前の形が実機 (`nvme-...`、`ata-...`) と違うので、VM 用の `disks.toml` を別に作り、本番の `disks.toml` を書き換えない。
- age の秘密鍵を戻す手順は人の操作で、時間に入る。
