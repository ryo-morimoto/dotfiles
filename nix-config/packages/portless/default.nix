{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "portless";
  version = "0.15.6";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha512-uOAwWLF32rmyEGFASzSO0VOaqb/AQxFCCzyZbPGd82UNNOfIEvc09zy92nroNibE5HNfzV4oVB0ObKbPXgkM9A==";
  };

  patches = [
    ./flat-worktree-hostnames.patch
    ./no-sudo-with-bind-capability.patch
  ];
  patchFlags = [
    "-p1"
    "--fuzz=0"
  ];

  prePatch = ''
    ${lib.getExe nodejs_24} <<'EOF'
    const pkg = require("./package.json");
    const expected = {
      name: "portless",
      version: "0.15.6",
      node: ">=24",
      bin: "./dist/cli.js",
      license: "Apache-2.0",
    };

    const actual = {
      name: pkg.name,
      version: pkg.version,
      node: pkg.engines?.node,
      bin: pkg.bin?.portless,
      license: pkg.license,
    };

    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`unexpected npm metadata: ''${JSON.stringify(actual)}`);
    }
    if (Object.keys(pkg.dependencies ?? {}).length !== 0) {
      throw new Error("portless npm artifact unexpectedly has runtime dependencies");
    }
    if (pkg.scripts?.install || pkg.scripts?.postinstall) {
      throw new Error("portless npm artifact unexpectedly has an install hook");
    }
    EOF
  '';

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-appQD4Yestz7d1HfDxdBcYjg/Bx4rEtWRTx+5S/l7rE=";
  forceEmptyCache = true;
  dontNpmBuild = true;

  postConfigure = ''
    mkdir -p node_modules
  '';

  preInstall = ''
    mkdir -p node_modules
  '';

  meta = {
    description = "Replace port numbers with stable, named local URLs";
    homepage = "https://portless.sh";
    license = lib.licenses.asl20;
    mainProgram = "portless";
    platforms = lib.platforms.unix;
  };
}
