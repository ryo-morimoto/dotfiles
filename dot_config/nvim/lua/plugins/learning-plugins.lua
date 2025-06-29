-- vimdoc-jaの公式日本語説明に準拠したwhich-keyマッピング

return {
  {
    "folke/which-key.nvim",
    -- 優先度を高く設定してLazyVimのデフォルト設定を確実に上書き
    priority = 1000,
    -- LazyVimの設定とマージせずに完全に置き換える
    opts_extend = false,
    opts = {
      preset = "modern",
      delay = 100,
      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 20,
        },
        presets = {
          operators = true,
          motions = true,
          text_objects = true,
          windows = true,
          nav = true,
          z = true,
          g = true,
        },
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      -- vimdoc-ja index.jax から抽出した公式の日本語説明
      wk.add({
        -- ===== 基本移動コマンド (motion.txt) =====
        { "h", desc = "左へ移動" },
        { "j", desc = "下へ移動" },
        { "k", desc = "上へ移動" },
        { "l", desc = "右へ移動" },
        { "w", desc = "次の単語の頭へ移動" },
        { "b", desc = "前の単語の頭へ移動" },
        { "e", desc = "単語の末尾へ移動" },
        { "0", desc = "行の先頭へ移動" },
        { "^", desc = "行の先頭の非空白文字へ移動" },
        { "$", desc = "行の末尾へ移動" },
        { "gg", desc = "ファイルの先頭へ移動" },
        { "G", desc = "ファイルの末尾へ移動 (N行目へ移動)" },
        { "f", group = "文字検索" },
        { "F", desc = "文字を左へ検索" },
        { "t", desc = "文字の手前まで右へ移動" },
        { "T", desc = "文字の手前まで左へ移動" },

        -- ===== 削除コマンド (change.txt) =====
        { "d", group = "削除" },
        { "dd", desc = "行を削除" },
        { "dw", desc = "単語を削除" },
        { "D", desc = "行末まで削除" },
        { "x", desc = "文字を削除" },
        { "X", desc = "前の文字を削除" },
        { "s", desc = "文字を削除して挿入モードに入る" },
        { "S", desc = "行を削除して挿入モードに入る" },

        -- ===== ヤンク(コピー)コマンド =====
        { "y", group = "ヤンク(コピー)" },
        { "yy", desc = "行をヤンク" },
        { "yw", desc = "単語をヤンク" },
        { "Y", desc = "行末までヤンク" },

        -- ===== 変更コマンド (change.txt) =====
        { "c", group = "変更" },
        { "cc", desc = "行を変更" },
        { "cw", desc = "単語を変更" },
        { "C", desc = "行末まで変更" },
        { "r", desc = "文字を置換" },
        { "R", desc = "置換モードに入る" },

        -- ===== プット(ペースト)コマンド =====
        { "p", desc = "カーソルの後にプット" },
        { "P", desc = "カーソルの前にプット" },

        -- ===== アンドゥ・リドゥ (undo.txt) =====
        { "u", desc = "アンドゥ" },
        { "<C-r>", desc = "リドゥ" },
        { "U", desc = "行のアンドゥ" },

        -- ===== 挿入モード (insert.txt) =====
        { "i", desc = "挿入モードに入る" },
        { "a", desc = "カーソルの後で挿入モードに入る" },
        { "I", desc = "行の先頭で挿入モードに入る" },
        { "A", desc = "行の末尾で挿入モードに入る" },
        { "o", desc = "下に新しい行を作って挿入モードに入る" },
        { "O", desc = "上に新しい行を作って挿入モードに入る" },

        -- ===== ビジュアルモード (visual.txt) =====
        { "v", desc = "ビジュアルモードを開始" },
        { "V", desc = "行ビジュアルモードを開始" },
        { "<C-v>", desc = "矩形ビジュアルモードを開始" },

        -- ===== 検索コマンド (pattern.txt) =====
        { "/", desc = "前方検索" },
        { "?", desc = "後方検索" },
        { "n", desc = "次の検索結果へ移動" },
        { "N", desc = "前の検索結果へ移動" },
        { "*", desc = "カーソル位置の単語を前方検索" },
        { "#", desc = "カーソル位置の単語を後方検索" },

        -- ===== ジャンプコマンド =====
        { "<C-o>", desc = "前のジャンプリストの場所へジャンプ" },
        { "<C-i>", desc = "次のジャンプリストの場所へジャンプ" },
        { "''", desc = "前のマーク位置へジャンプ" },
        { "``", desc = "前のマーク位置へジャンプ(カラム位置も)" },

        -- ===== マークコマンド =====
        { "m", group = "マーク" },
        { "'", group = "マークへジャンプ (行)" },
        { "`", group = "マークへジャンプ (位置)" },

        -- ===== レジスタコマンド =====
        { '"', group = "レジスタ" },

        -- ===== ウィンドウコマンド (windows.txt) =====
        { "<C-w>", group = "ウィンドウコマンド" },
        { "<C-w>h", desc = "左のウィンドウへ移動" },
        { "<C-w>j", desc = "下のウィンドウへ移動" },
        { "<C-w>k", desc = "上のウィンドウへ移動" },
        { "<C-w>l", desc = "右のウィンドウへ移動" },
        { "<C-w>s", desc = "ウィンドウを水平分割" },
        { "<C-w>v", desc = "ウィンドウを垂直分割" },
        { "<C-w>c", desc = "ウィンドウを閉じる" },
        { "<C-w>o", desc = "このウィンドウ以外を閉じる" },
        { "<C-w>w", desc = "次のウィンドウへ移動" },
        { "<C-w>p", desc = "前のウィンドウへ移動" },
        { "<C-w>r", desc = "ウィンドウを回転" },
        { "<C-w>x", desc = "ウィンドウを交換" },
        { "<C-w>=", desc = "ウィンドウサイズを均等に" },
        { "<C-w>+", desc = "ウィンドウの高さを増やす" },
        { "<C-w>-", desc = "ウィンドウの高さを減らす" },
        { "<C-w>>", desc = "ウィンドウの幅を増やす" },
        { "<C-w><", desc = "ウィンドウの幅を減らす" },

        -- ===== スクロールコマンド (scroll.txt) =====
        { "<C-f>", desc = "1画面下へスクロール" },
        { "<C-b>", desc = "1画面上へスクロール" },
        { "<C-d>", desc = "半画面下へスクロール" },
        { "<C-u>", desc = "半画面上へスクロール" },
        { "<C-e>", desc = "1行下へスクロール" },
        { "<C-y>", desc = "1行上へスクロール" },

        -- ===== その他の重要なコマンド =====
        { ".", desc = "前回の変更を繰り返し" },
        { "~", desc = "文字の大文字小文字を切り替え" },
        { "<C-a>", desc = "数字に加算" },
        { "<C-x>", desc = "数字から減算" },
        { "J", desc = "行を連結" },
        { "K", desc = "カーソル位置の単語のマニュアルを表示" },
        { "H", desc = "画面の上部へ移動" },
        { "M", desc = "画面の中央へ移動" },
        { "L", desc = "画面の下部へ移動" },
        { "zt", desc = "カーソル行を画面の上部に" },
        { "zz", desc = "カーソル行を画面の中央に" },
        { "zb", desc = "カーソル行を画面の下部に" },

        -- ===== gプレフィックスコマンド =====
        { "g", group = "gコマンド" },
        { "gg", desc = "ファイルの先頭へ移動" },
        { "gd", desc = "ローカル宣言へジャンプ" },
        { "gD", desc = "グローバル宣言へジャンプ" },
        { "gf", desc = "カーソル位置のファイルを開く" },
        { "gx", desc = "カーソル位置のURLを開く" },
        { "gi", desc = "最後に挿入した位置へ移動" },
        { "gv", desc = "前回の選択範囲を再選択" },
        { "gj", desc = "表示行で下へ移動" },
        { "gk", desc = "表示行で上へ移動" },
        { "g0", desc = "表示行の先頭へ移動" },
        { "g$", desc = "表示行の末尾へ移動" },
        { "gq", desc = "テキストを整形" },
        { "gw", desc = "テキストを整形(カーソル位置保持)" },
        { "gu", desc = "小文字に変換" },
        { "gU", desc = "大文字に変換" },
        { "g~", desc = "大文字小文字を反転" },

        -- ===== zプレフィックスコマンド (折り畳み等) =====
        { "z", group = "zコマンド(折り畳み・表示)" },
        { "zf", desc = "折り畳みを作成" },
        { "zo", desc = "折り畳みを開く" },
        { "zc", desc = "折り畳みを閉じる" },
        { "za", desc = "折り畳みを切り替え" },
        { "zd", desc = "折り畳みを削除" },
        { "zE", desc = "すべての折り畳みを削除" },
        { "zR", desc = "すべての折り畳みを開く" },
        { "zM", desc = "すべての折り畳みを閉じる" },
        { "zr", desc = "折り畳みレベルを減らす" },
        { "zm", desc = "折り畳みレベルを増やす" },
        { "zi", desc = "折り畳み機能を切り替え" },
        { "zj", desc = "次の折り畳みへ移動" },
        { "zk", desc = "前の折り畳みへ移動" },
        { "zt", desc = "カーソル行を画面の上部に" },
        { "zz", desc = "カーソル行を画面の中央に" },
        { "zb", desc = "カーソル行を画面の下部に" },
        { "zh", desc = "画面を右へスクロール" },
        { "zl", desc = "画面を左へスクロール" },
        { "zH", desc = "画面を半画面右へスクロール" },
        { "zL", desc = "画面を半画面左へスクロール" },

        -- ===== 角括弧コマンド =====
        { "[", group = "前方向コマンド" },
        { "]", group = "後方向コマンド" },
        { "[[", desc = "前のセクション開始へ移動" },
        { "]]", desc = "次のセクション開始へ移動" },
        { "[]", desc = "前のセクション終了へ移動" },
        { "][", desc = "次のセクション終了へ移動" },
        { "[{", desc = "対応する { へ移動" },
        { "]}", desc = "対応する } へ移動" },
        { "[(", desc = "対応する ( へ移動" },
        { "])", desc = "対応する ) へ移動" },

        -- ===== テキストオブジェクト =====
        { "i", group = "内側テキストオブジェクト", mode = "o" },
        { "a", group = "外側テキストオブジェクト", mode = "o" },
        { "iw", desc = "単語内", mode = "o" },
        { "aw", desc = "単語全体", mode = "o" },
        { "is", desc = "文内", mode = "o" },
        { "as", desc = "文全体", mode = "o" },
        { "ip", desc = "段落内", mode = "o" },
        { "ap", desc = "段落全体", mode = "o" },
        { "i(", desc = "()内", mode = "o" },
        { "a(", desc = "()含む", mode = "o" },
        { "i[", desc = "[]内", mode = "o" },
        { "a[", desc = "[]含む", mode = "o" },
        { "i{", desc = "{}内", mode = "o" },
        { "a{", desc = "{}含む", mode = "o" },
        { 'i"', desc = '""内', mode = "o" },
        { 'a"', desc = '""含む', mode = "o" },
        { "i'", desc = "''内", mode = "o" },
        { "a'", desc = "''含む", mode = "o" },
        { "i`", desc = "``内", mode = "o" },
        { "a`", desc = "``含む", mode = "o" },
        { "it", desc = "タグ内", mode = "o" },
        { "at", desc = "タグ含む", mode = "o" },

        -- ===== コマンドライン =====
        { ":", desc = "Exコマンドライン" },
        { "!", desc = "フィルタコマンド" },
        { "q:", desc = "コマンドライン履歴ウィンドウ" },
        { "q/", desc = "検索履歴ウィンドウ" },
        { "q?", desc = "検索履歴ウィンドウ" },

        -- ===== その他の制御キー =====
        { "<Esc>", desc = "ノーマルモードに戻る" },
        { "<CR>", desc = "改行文字(Enter)" },
        { "<BS>", desc = "バックスペース" },
        { "<Tab>", desc = "タブ文字" },
        { "<Space>", desc = "空白文字(l と同じ)" },

        -- ===== 学習支援メニュー =====
        { "<leader>", group = "リーダーキー" },
        { "<leader>h", group = "ヘルプ" },
        { "<leader>hh", "<cmd>help<cr>", desc = "ヘルプを開く" },
        { "<leader>ht", "<cmd>Tutor<cr>", desc = "Vimチュートリアル" },
        { "<leader>hi", "<cmd>help index<cr>", desc = "コマンド索引" },
        { "<leader>hm", "<cmd>help motion<cr>", desc = "移動コマンドヘルプ" },
        { "<leader>hc", "<cmd>help change<cr>", desc = "変更コマンドヘルプ" },
        { "<leader>hv", "<cmd>help visual<cr>", desc = "ビジュアルモードヘルプ" },
        { "<leader>hw", "<cmd>help windows<cr>", desc = "ウィンドウヘルプ" },
        { "<leader>ho", "<cmd>help options<cr>", desc = "オプションヘルプ" },

        -- LazyVimデフォルトメニューの日本語化
        { "<leader>f", group = "ファイル操作" },
        { "<leader>s", group = "検索" },
        { "<leader>b", group = "バッファ" },
        { "<leader>w", group = "ウィンドウ" },
        { "<leader>c", group = "コード" },
        { "<leader>g", group = "Git" },
        { "<leader>t", group = "ターミナル" },
        { "<leader>u", group = "UI" },
        { "<leader>x", group = "診断/トラブル" },
      })

      -- ビジュアルモード専用マッピング
      wk.add({
        mode = "v",
        { "d", desc = "選択範囲を削除" },
        { "y", desc = "選択範囲をヤンク" },
        { "c", desc = "選択範囲を変更" },
        { "x", desc = "選択範囲を削除" },
        { "s", desc = "選択範囲を削除して挿入" },
        { "r", desc = "選択範囲を置換" },
        { "u", desc = "選択範囲を小文字に" },
        { "U", desc = "選択範囲を大文字に" },
        { "~", desc = "選択範囲の大文字小文字を反転" },
        { ">", desc = "選択範囲をインデント" },
        { "<", desc = "選択範囲のインデントを削除" },
        { "=", desc = "選択範囲を自動インデント" },
        { "J", desc = "選択行を連結" },
        { "gq", desc = "選択範囲を整形" },
        { "gw", desc = "選択範囲を整形(カーソル位置保持)" },
        { "o", desc = "選択範囲の反対端へ移動" },
        { "O", desc = "選択範囲の反対端へ移動(行)" },
      })

      -- 挿入モード用の主要マッピング（参考用）
      wk.add({
        mode = "i",
        { "<C-n>", desc = "次の補完候補" },
        { "<C-p>", desc = "前の補完候補" },
        { "<C-x>", desc = "補完サブモード" },
        { "<C-o>", desc = "ノーマルモードコマンドを1つ実行" },
        { "<C-r>", desc = "レジスタの内容を挿入" },
        { "<C-t>", desc = "行をシフト幅分右へ" },
        { "<C-d>", desc = "行をシフト幅分左へ" },
        { "<C-w>", desc = "前の単語を削除" },
        { "<C-u>", desc = "行頭まで削除" },
        { "<C-k>", desc = "行末まで削除" },
        { "<C-y>", desc = "上の行の文字をコピー" },
        { "<C-e>", desc = "下の行の文字をコピー" },
        { "<C-a>", desc = "前回挿入したテキストを挿入" },
        { "<C-v>", desc = "次の文字を文字通り挿入" },
        { "<Esc>", desc = "ノーマルモードに戻る" },
        { "<C-[>", desc = "ノーマルモードに戻る" },
      })
    end,
  },
}
