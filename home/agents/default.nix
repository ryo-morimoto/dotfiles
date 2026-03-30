{
  config,
  pkgs,
  lib,
  ...
}:

let
  pencilMcp = pkgs.writeShellScript "pencil-mcp" ''
    if [ -z "$PENCIL_MCP_PATH" ]; then
      echo "PENCIL_MCP_PATH is not set. Run Pencil AppImage once to initialize." >&2
      exit 1
    fi
    exec "$PENCIL_MCP_PATH" "$@"
  '';

  pencilMcpBinaryRelPath = "resources/app.asar.unpacked/out/mcp-server-linux-x64";
  pencilAppImagePath = "${config.home.homeDirectory}/Applications/Pencil.AppImage";
  pencilMcpPathFile = "${config.xdg.cacheHome}/pencil-mcp-path";
in
{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./opencode.nix
    ./skills.nix
  ];

  # Discover Pencil MCP server path from AppImage cache on activation
  home.activation.discoverPencilMcpPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pencil_appimage="${pencilAppImagePath}"
    cache_dir="${config.xdg.cacheHome}/appimage-run"
    mcp_rel="${pencilMcpBinaryRelPath}"
    path_file="${pencilMcpPathFile}"

    if [ -f "$pencil_appimage" ] && [ -d "$cache_dir" ]; then
      found=""
      for dir in "$cache_dir"/*/; do
        candidate="$dir$mcp_rel"
        if [ -x "$candidate" ]; then
          found="$candidate"
          break
        fi
      done
      if [ -n "$found" ]; then
        printf "%s\n" "$found" > "$path_file"
      fi
    fi
  '';

  _module.args.pencilMcp = pencilMcp;
}
