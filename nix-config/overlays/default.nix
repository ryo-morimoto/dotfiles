# nixpkgs から離脱する package 定義・override はすべてここに集約する。
# 新規追加はユーザー許可を得てから行う(AGENTS.md 参照)。
{ inputs }:
{
  # repo local の自作 package
  local = final: _prev: {
    # Official Linux .deb wrap. nixpkgs.chatgpt is still Darwin-only
    # (nixpkgs#551713 / #551852).
    chatgpt = final.callPackage ../packages/chatgpt { };
    portless = final.callPackage ../packages/portless { };
  };

  # nixpkgs / 他 overlay の package への override と外部 flake package の注入。
  community = final: prev: {
    catppuccin-gtk = prev.catppuccin-gtk.override {
      python3 = prev.python3.override {
        packageOverrides = _pythonFinal: pythonPrev: {
          catppuccin = pythonPrev.catppuccin.overridePythonAttrs (_old: {
            doCheck = false;
            pythonImportsCheck = [ ];
          });
        };
      };
    };
    # Temporary(NixOS/nixpkgs#531687): Qt 6.12 の uic が "::" 始まりのクラス名を拒否する
    # (google/mozc#1594)。tools/nixpkgs-pending が lock への到着を検知して削除 PR を作る。
    mozc = prev.mozc.overrideAttrs (old: {
      postPatch = old.postPatch + ''
        substituteInPlace src/gui/dictionary_tool/dictionary_tool.ui \
          --replace-fail "::mozc::gui::DictionaryContentTableWidget" "mozc::gui::DictionaryContentTableWidget"
      '';
    });
    zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
    seiren-mcp = inputs.seiren.packages.${final.stdenv.hostPlatform.system}.default;
    soulforge = inputs.soulforge.packages.${final.stdenv.hostPlatform.system}.default;
  };
}
