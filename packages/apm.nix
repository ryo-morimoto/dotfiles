{
  autoPatchelfHook ? null,
  fetchurl ? null,
  git ? null,
  lib,
  makeWrapper ? null,
  openssl ? null,
  openssh ? null,
  stdenv ? null,
  stdenvNoCC ? null,
  zlib ? null,
}:

let
  dsl =
    let
      fail = message: throw "apm-dsl: ${message}";
      formatList = values: lib.concatStringsSep ", " values;

      getPin =
        lock: package:
        if builtins.hasAttr package lock then
          lock.${package}
        else
          fail "missing lock entry for package '${package}'";

      mkPinnedDependency =
        {
          lock,
          package,
          path ? null,
        }:
        let
          pin = getPin lock package;
          suffix = if path == null then "" else "/${path}";
        in
        "${pin.source}${suffix}#${pin.rev}";

      getInput =
        inputs: input:
        if builtins.hasAttr input inputs then inputs.${input} else fail "missing flake input '${input}'";

      getInputRev =
        inputName: input:
        if builtins.hasAttr "rev" input then
          input.rev
        else
          fail "flake input '${inputName}' does not expose a rev";

      mkInputPin =
        inputs: package: spec:
        let
          normalizedSpec = if builtins.isString spec then { source = spec; } else spec;
          inputName = normalizedSpec.input or package;
          input = getInput inputs inputName;
          source = normalizedSpec.source or (fail "package '${package}' must declare an APM source");
          sourcePath = normalizedSpec.path or null;
          sourceSuffix = if sourcePath == null then "" else "/${sourcePath}";
        in
        {
          source = "${source}${sourceSuffix}";
          rev = normalizedSpec.rev or (getInputRev inputName input);
        };

      mkInputLock =
        {
          inputs,
          packages,
        }:
        lib.mapAttrs (mkInputPin inputs) packages;

      normalizeRequires =
        node:
        let
          requires = node.requires or { };
        in
        {
          skills = requires.skills or [ ];
          agents = requires.agents or [ ];
        };

      assertKnown =
        kind: known: owner: refs:
        let
          missing = builtins.filter (name: !(builtins.hasAttr name known)) refs;
        in
        if missing == [ ] then true else fail "${owner} references unknown ${kind}: ${formatList missing}";

      assertAgentLeaves =
        agents:
        let
          invalid = builtins.filter (name: agents.${name} ? requires) (builtins.attrNames agents);
        in
        if invalid == [ ] then
          true
        else
          fail "agents must be dependency leaves, but these declare requires: ${formatList invalid}";
    in
    {
      inherit
        mkInputLock
        mkPinnedDependency
        ;

      mkPackageDependency =
        {
          lock,
          package,
          path ? null,
        }:
        mkPinnedDependency {
          inherit
            lock
            package
            path
            ;
        };

      mkPrimitiveDependencies =
        {
          lock,
          package,
          selectedSkills,
          skills,
          agents ? { },
          skillPath ? (name: "skills/${name}"),
          agentPath ? (name: "agents/${name}.agent.md"),
        }:
        let
          closeSkill =
            stack: name:
            if builtins.elem name stack then
              fail "skill dependency cycle detected: ${formatList (stack ++ [ name ])}"
            else if !(builtins.hasAttr name skills) then
              fail "selectedSkills references unknown skill: ${name}"
            else
              let
                requires = normalizeRequires skills.${name};
              in
              builtins.deepSeq [
                (assertKnown "skill" skills "skill '${name}'" requires.skills)
                (assertKnown "agent" agents "skill '${name}'" requires.agents)
              ] ([ name ] ++ builtins.concatLists (map (closeSkill (stack ++ [ name ])) requires.skills));

          validateSkill =
            name:
            let
              requires = normalizeRequires skills.${name};
            in
            builtins.deepSeq [
              (assertKnown "skill" skills "skill '${name}'" requires.skills)
              (assertKnown "agent" agents "skill '${name}'" requires.agents)
            ] true;

          skillClosure = lib.unique (builtins.concatLists (map (closeSkill [ ]) selectedSkills));
          agentClosure = lib.unique (
            builtins.concatLists (map (name: (normalizeRequires skills.${name}).agents) skillClosure)
          );
          validations = (map validateSkill (builtins.attrNames skills)) ++ [ (assertAgentLeaves agents) ];
        in
        builtins.deepSeq validations (
          (map (
            name:
            mkPinnedDependency {
              inherit lock package;
              path = skillPath name;
            }
          ) skillClosure)
          ++ (map (
            name:
            mkPinnedDependency {
              inherit lock package;
              path = agentPath name;
            }
          ) agentClosure)
        );
    };

  homeManagerModule =
    {
      config,
      lib,
      pkgs,
      sharedApm,
      ...
    }:

    let
      yaml = pkgs.formats.yaml { };
      apmManifestFile = yaml.generate "apm.yml" sharedApm.manifest;
      targetArg = lib.concatStringsSep "," sharedApm.targets;
      updateArg = lib.optionalString (sharedApm.update or true) " --update";
      codexSettings = config.programs.codex.settings or { };
      codexSettingsFile = (pkgs.formats.toml { }).generate "codex-settings.toml" codexSettings;
      installsCodex = builtins.elem "codex" sharedApm.targets;
      shouldMergeCodexSettings = installsCodex && codexSettings != { };
      codexConfigStash = "$HOME/.cache/apm/codex-config-before-home-manager.toml";
    in
    {
      home = {
        packages = [
          pkgs.apm
        ];

        file.".apm/apm.yml".source = apmManifestFile;

        activation.apmStashCodexConfig = lib.mkIf shouldMergeCodexSettings (
          lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
            codex_config="$HOME/.codex/config.toml"
            codex_config_stash="${codexConfigStash}"

            if [ -f "$codex_config" ] && [ ! -L "$codex_config" ]; then
              mkdir -p "$(dirname "$codex_config_stash")"
              install -m 0600 "$codex_config" "$codex_config_stash"
              rm "$codex_config"
            fi
          ''
        );

        activation.apmInstallAgentPackages = lib.mkIf sharedApm.enable (
          lib.hm.dag.entryAfter
            [
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

              codex_config="$HOME/.codex/config.toml"
              if [ -L "$codex_config" ]; then
                codex_config_target="$(readlink "$codex_config")"
                case "$codex_config_target" in
                  /nix/store/*) rm "$codex_config" ;;
                esac
              fi

              cd "$HOME/.apm"
              ${pkgs.apm}/bin/apm install -g --target ${lib.escapeShellArg targetArg}${updateArg}
              ${pkgs.apm}/bin/apm prune

              ${lib.optionalString shouldMergeCodexSettings ''
                mkdir -p "$HOME/.codex"

                current_json="$(mktemp)"
                codex_settings_json="$(mktemp)"
                merged_json="$(mktemp)"
                merged_toml="$(mktemp)"
                cleanup_codex_settings_merge() {
                  rm -f "$current_json" "$codex_settings_json" "$merged_json" "$merged_toml"
                }
                trap cleanup_codex_settings_merge EXIT

                codex_config_stash="${codexConfigStash}"
                if [ -e "$codex_config_stash" ]; then
                  ${lib.getExe pkgs.remarshal} -f toml -t json "$codex_config_stash" "$current_json"
                  rm "$codex_config_stash"
                elif [ -e "$codex_config" ]; then
                  ${lib.getExe pkgs.remarshal} -f toml -t json "$codex_config" "$current_json"
                else
                  printf '{}\n' > "$current_json"
                fi

                ${lib.getExe pkgs.remarshal} -f toml -t json "${codexSettingsFile}" "$codex_settings_json"
                ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$current_json" "$codex_settings_json" > "$merged_json"
                ${lib.getExe pkgs.remarshal} -f json -t toml "$merged_json" "$merged_toml"

                install -m 0600 "$merged_toml" "$codex_config"
              ''}
            ''
        );
      };
    };

  package = stdenvNoCC.mkDerivation rec {
    pname = "apm";
    version = "0.14.2";

    src = fetchurl {
      url = "https://github.com/microsoft/apm/releases/download/v${version}/apm-linux-x86_64.tar.gz";
      hash = "sha256-mAt7AeQ7xpu+NJs+AbddSDdBKwJ7/RGK5ubKRnuAEog=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = [
      openssl
      stdenv.cc.cc.lib
      zlib
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/apm" "$out/bin"
      cp -R . "$out/lib/apm/"
      chmod +x "$out/lib/apm/apm"
      makeWrapper "$out/lib/apm/apm" "$out/bin/apm" \
        --prefix PATH : "${
          lib.makeBinPath [
            git
            openssh
          ]
        }"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/apm --version >/dev/null
    '';

    passthru = {
      inherit dsl homeManagerModule;
    };

    meta = with lib; {
      description = "Agent Package Manager for AI agent configuration";
      homepage = "https://github.com/microsoft/apm";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "apm";
    };
  };
in
if stdenvNoCC == null then
  {
    inherit dsl homeManagerModule;
  }
else
  package
