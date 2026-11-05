# 宣言の適用

パッケージやサービスの宣言を変えると、全体を作り直さずに分単位で使えるようになる。宣言されていない状態は1コマンドで一覧でき、その一覧は空か、理由を書いた既知のものだけである。

## Sub-features

- `decman-clean-before`: 宣言と実機に差が無い (`decman --dry-run` が何もしない)。
- `declare-add`: 宣言にパッケージを1つ足して `sudo decman` を実行すると、分単位で使える (MNT-2)。
- `declare-remove`: 足したものを宣言から外すと、消える。
- `undeclared-state`: 宣言されていない状態の一覧が、空か既知のものだけ (INT-3)。

## How to get to it (user POV)

- dotfiles の decman の宣言 (段階5で置く) に、パッケージ名を1行足して、`sudo decman` を実行する。
- `docs/platform/desktop/functional/undeclared.sh` を実行して一覧を見る。

## Driving it with dv

Preconditions:

- 実機。`dv doctor` が fail を出さない。
- 試すパッケージ (既定は `cowsay`) が入っていない。違うものを使うときは `DV_PROBE_PACKAGE` に書く。

Steps:

- **適用前の確認。** `docs/platform/desktop/functional/dv drive declare-apply` を実行する。`decman-clean-before` と `undeclared-state` が自動で走る。
- **足す (人の操作)。** decman の宣言に `cowsay` を足して、`time sudo decman` を実行する。`cowsay hello` が動くことを確かめる。`time` の出力を証拠のフォルダの `declare-add.txt` に置く。数分以内なら pass。
- **外す (人の操作)。** 宣言から `cowsay` を外して `sudo decman` を実行し、`command -v cowsay` が何も返さないことを確かめる。`declare-remove.txt` に置く。
- **最後の確認。** もう一度 `dv drive declare-apply` を実行し、`decman-clean-before` が pass に戻ることを確かめる。

## Gotchas

- decman は systemd のユニットを有効にするだけで、起動はしない。サービスを足したときは、`systemctl start` か再起動の後で確かめる。
- decman を実行するたびに snap-pac がスナップショットを取る。そのため、ADR-0002 の押し出しを止めるフックが、何度目かで更新を止めることがある。これは仕様どおりなので、再起動してログインしてから続ける。
- `undeclared.sh` の既知の一覧 (`known-undeclared.txt`) に足すときは、なぜ宣言しないかをコメントで書く。理由の無い行は足さない。
