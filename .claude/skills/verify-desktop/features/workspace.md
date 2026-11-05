# 作業面

電源を入れてログインすると、niri のセッションが2画面とも 1920x1080 / 144Hz で上がる。日本語入力 (fcitx5 + hazkey)、クリップボード、スクリーンショット、画面共有が使える。DMS の設定画面で変えた値は、手書きの設定より優先して効く。

## Sub-features

- `session-wayland`: ログインしたセッションが Wayland の niri である。
- `outputs-2x144`: 2画面とも 1920x1080 で、リフレッシュレートが 143Hz 以上。
- `ime-hazkey`: fcitx5 が動き、入力メソッドに hazkey がある。
- `clipboard`: `wl-copy` と `wl-paste` で値が往復する。
- `screenshot`: niri のスクリーンショットが、画像のフォルダに書かれる。
- `screencast-portal`: 画面共有の portal (`org.freedesktop.portal.Desktop`) が応答する。
- `niri-layers-lint`: niri 設定の層が D-V2 の R1 / R2 を満たす。
- `niri-validate`: niri が設定を受け付ける。
- `boot-time`: 電源投入からログインできるまで 60 秒以内 (PERF-4、MAY)。

## How to get to it (user POV)

- 電源を入れ、ログイン画面 (dms-greeter) でログインする。
- `Mod+T` などのキーで端末を開き、日本語を入力する。
- DMS の設定画面で、画面のモードや色を変える。

## Driving it with dv

Preconditions:

- 実機で、niri のセッションにログインした端末から実行する (`XDG_SESSION_ID` と `WAYLAND_DISPLAY` がある)。
- 2台の画面がつながっている。

Steps:

- **自動の確認。** `docs/platform/desktop/functional/dv drive workspace` を実行する。`outputs-2x144` は `niri msg --json outputs` の現在のモードを読む。`niri msg --json outputs` の出力そのものも証拠に残る。
- **日本語入力 (人の操作)。** ghostty を開いて `Ctrl+Space` で hazkey に切り替え、「にほんご」と打って「日本語」に変換し、確定する。画面を `niri msg action screenshot-screen` で撮り、証拠のフォルダに `ime.png` として置く。
- **DMS の設定画面が勝つこと (人の操作)。** DMS の設定画面で、画面1のリフレッシュレートを 60Hz にする。`niri msg --json outputs` で 60Hz になったことを確かめ、144Hz に戻す。前後の出力を `dms-ui-write.txt` に置く。`~/.config/niri/local.kdl` に output 節が無いことは `niri-layers-lint` が確かめる。
- **ログインまでの時間。** `boot-time` は `systemd-analyze` の合計を見る。合計にはログインの操作が入らないので、ログイン画面が出るまでの時間に近い。

## Gotchas

- `niri msg --json outputs` の `refresh_rate` はミリヘルツである (例: 143981)。144000 ちょうどではないので、143000 以上で判定する。
- `screenshot` は、画像のフォルダ (`xdg-user-dir PICTURES`) が niri の `screenshot-path` と一致している前提である。違えば、niri の設定に合わせて直す。
- 日本語入力と DMS の設定画面は GUI の操作なので、自動にはしない。人の操作の証拠 (スクリーンショット、前後の出力) が無いときは skip とする。
- 代わりの環境では動かさない (GPU と画面が要る)。
