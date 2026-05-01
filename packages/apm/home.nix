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
        ''
    );
  };
}
