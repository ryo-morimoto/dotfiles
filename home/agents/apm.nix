{
  lib,
  pkgs,
  sharedApm,
  ...
}:

let
  yaml = pkgs.formats.yaml { };
  apmManifestFile = yaml.generate "apm.yml" sharedApm.manifest;
  targetArg = lib.concatStringsSep "," sharedApm.targets;
  superpowersClaudeSessionStartHook = pkgs.writeShellApplication {
    name = "superpowers-claude-session-start";
    text = ''
      set -euo pipefail

      export CLAUDE_PLUGIN_ROOT="$HOME/.apm/apm_modules/obra/superpowers"
      exec "$CLAUDE_PLUGIN_ROOT/hooks/run-hook.cmd" session-start
    '';
  };
in
{
  home = {
    packages = [
      pkgs.apm
    ];

    file.".apm/apm.yml".source = apmManifestFile;

    activation.apmInstallAgentPackages = lib.mkIf sharedApm.enable (
      lib.hm.dag.entryAfter
        [
          "agent-skills"
          "claudeCodeSettings"
          "linkGeneration"
        ]
        ''
          export PATH="${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.git
              pkgs.openssh
            ]
          }:$PATH"

          cd "$HOME/.apm"
          ${pkgs.apm}/bin/apm install -g --target ${lib.escapeShellArg targetArg} --only=apm

          claude_settings="$HOME/.claude/settings.json"
          superpowers_root="$HOME/.apm/apm_modules/obra/superpowers"
          if [ -f "$claude_settings" ] && [ -d "$superpowers_root" ]; then
            superpowers_hook_command="${superpowersClaudeSessionStartHook}/bin/superpowers-claude-session-start"
            ${pkgs.jq}/bin/jq --arg superpowersHookCommand "$superpowers_hook_command" '
              del(.hooks.sessionStart)
              | if ((.hooks.SessionStart? | type) == "array") then
                  .hooks.SessionStart = (
                    .hooks.SessionStart
                    | map(.hooks = ((.hooks // []) | map(if ((.command? // "") | contains("''${CLAUDE_PLUGIN_ROOT}")) then .command = $superpowersHookCommand else . end)))
                    | unique_by((.matcher // ""), (.hooks | tostring))
                  )
                else . end
            ' "$claude_settings" > "$claude_settings.tmp"
            mv "$claude_settings.tmp" "$claude_settings"
          fi
        ''
    );
  };
}
