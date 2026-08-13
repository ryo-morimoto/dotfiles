# nixpkgs から離脱する package 定義・override はすべてここに集約する。
# 新規追加はユーザー許可を得てから行う(AGENTS.md 参照)。
{ inputs }:
{
  # repo local の自作 package
  local = final: _prev: {
    portless = final.callPackage ../packages/portless { };
  };

  # nixpkgs / 他 overlay の package への override と外部 flake package の注入。
  # codex-cli-nix の overlay より後に適用すること(codex を上書きするため)。
  community = final: prev: {
    codex = prev.codex.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        substituteInPlace "$out/bin/codex" \
          --replace-fail "exec \"$out/bin/codex-raw\"  \"\$@\"" \
                         "exec -a codex \"$out/bin/codex-raw\" \"\$@\""
      '';
    });
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
    zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
    seiren-mcp = inputs.seiren.packages.${final.stdenv.hostPlatform.system}.default;
    soulforge = inputs.soulforge.packages.${final.stdenv.hostPlatform.system}.default;
  };
}
