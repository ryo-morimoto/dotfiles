{
  lib,
  rustPlatform,
  pkg-config,
  openssl,
  git,
  jq,
  curl,
  makeWrapper,
}:

rustPlatform.buildRustPackage {
  pname = "sandbox-broker";
  version = "0.1.0";

  src = ../tools/sandbox-broker;

  cargoHash = "sha256-9utXKXG47O6za4xo8uSMZU1v0OJCMokCUz0aXK5Vqms=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  nativeCheckInputs = [
    git
    jq
    curl
  ];

  buildInputs = [
    openssl
  ];

  postInstall = ''
    # Install adapter hook scripts alongside the binary
    mkdir -p $out/libexec/sandbox-broker
    for hook in $src/adapter/*.sh; do
      install -Dm755 "$hook" "$out/libexec/sandbox-broker/$(basename "$hook")"
    done

    # Wrap hook scripts so jq and curl are on PATH
    for script in $out/libexec/sandbox-broker/*.sh; do
      wrapProgram "$script" \
        --prefix PATH : ${
          lib.makeBinPath [
            jq
            curl
          ]
        }
    done
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/sandbox-broker help 2>&1 | grep -q "sandbox-broker"
  '';

  meta = with lib; {
    description = "Unified sandbox permission broker for AI coding agents";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sandbox-broker";
  };
}
