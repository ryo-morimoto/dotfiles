{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "portless";
  version = "0.15.5";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha512-zmJu4Q8/fY54oVUT/5NnmF4Ih8wTdCvCf6JCN783dRYl9mXkJBzXSckX2lztGCLIbM70varDjCudAbGKT73XPg==";
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
      version: "0.15.5",
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

  npmDepsHash = "sha256-NhuqCS86DhwOi+MLdW2JhtLR2eaObPBbGHKi52nW4TY=";
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
