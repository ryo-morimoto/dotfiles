# Quickshell Wallpaper Picker Design

## Overview

Quickshell ベースの壁紙ピッカーウィジェット。画面下部にオーバーレイ表示され、大きなサムネイルから壁紙を選択できる。

## UI

```
┌──────────────────────────────────────────────┐
│ (現在の画面が半透明で見える)                    │
│                                              │
├──────────────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ←→    │  横スクロール
│  │      │ │      │ │      │ │      │        │
│  │ 画像 │ │ 画像 │ │ 画像 │ │ 画像 │        │  200x120px
│  │      │ │      │ │      │ │      │        │
│  └──────┘ └──────┘ └──────┘ └──────┘        │
│   name1    name2    name3    name4          │  ファイル名
└──────────────────────────────────────────────┘
  半透明ダーク背景 rgba(20, 20, 30, 0.75)
```

## 動作

- `Mod+P` で下からスライドイン
- 左右キーまたはマウスでスクロール
- クリックまたはEnterで選択 → swww適用 → wallust実行 → 自動で閉じる
- Escでキャンセル

## ファイル構成

```
config/quickshell/
├── shell.qml          # エントリポイント
└── WallpaperPicker/
    ├── Main.qml       # メインコンポーネント
    ├── Thumbnail.qml  # サムネイルアイテム
    └── wallpaper.js   # swww/wallust連携
```

## 依存関係

- Quickshell (flake)
- Qt6 (Quickshell依存)
- swww (既存)
- wallust (既存)

## データフロー

### 起動
1. Mod+P → Niri が quickshell IPC 実行
2. WallpaperPicker スライドイン
3. ~/.config/wallpaper/ から画像読み込み
4. サムネイルグリッド表示

### 選択
1. 画像クリック
2. swww img <path> --transition-type grow
3. wallust run <path>
4. reload-theme.sh 実行
5. ピッカー閉じる

## スタイル

| 要素 | 値 |
|------|-----|
| 背景 | rgba(20, 20, 30, 0.75) |
| 角丸 | 12px (上側のみ) |
| パディング | 20px |
| サムネイル | 200x120px, 角丸 8px |
| 選択ボーダー | 2px solid #7e9cd8 |
| ファイル名色 | #dcd7ba |

## アニメーション

- 表示: 200ms ease-out スライドイン
- 非表示: 150ms ease-in スライドアウト
- ホバー: scale 1.05 + ボーダー

## キーバインド

| キー | 動作 |
|------|------|
| ← → | フォーカス移動 |
| Enter | 選択実行 |
| Esc | キャンセル |

## エラーハンドリング

- 画像フォルダ空 → "No wallpapers found" 表示
- swww 失敗 → 通知、ピッカー開いたまま
- wallust 失敗 → 壁紙適用済み、警告のみ

## NixOS 連携

1. flake.nix に quickshell input 追加
2. home.packages に quickshell 追加
3. xdg.configFile で QML 配置
