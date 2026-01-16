# ralph-tui - AI Agent Loop Orchestrator
# https://github.com/subsy/ralph-tui
#
# To regenerate bun.nix:
#   1. git clone https://github.com/subsy/ralph-tui
#   2. cd ralph-tui && nix develop github:nix-community/bun2nix
#   3. bun2nix -o bun.nix
#   4. cp bun.nix /path/to/dotfiles/packages/ralph-tui/
{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
	pname = "ralph-tui";
	version = "0.1.7";

	src = pkgs.fetchFromGitHub {
		owner = "subsy";
		repo = "ralph-tui";
		rev = "v0.1.7";
		# Run `nix build .#homeConfigurations.ryo-morimoto.activationPackage` to get correct hash
		hash = pkgs.lib.fakeHash;
	};

	nativeBuildInputs = [
		pkgs.bun2nix.hook
	];

	bunDeps = pkgs.bun2nix.fetchBunDeps {
		bunNix = ./bun.nix;
	};

	buildPhase = ''
		runHook preBuild
		bun build src/cli.ts --compile --outfile ralph-tui
		runHook postBuild
	'';

	installPhase = ''
		runHook preInstall
		mkdir -p $out/bin
		cp ralph-tui $out/bin/
		runHook postInstall
	'';

	meta = with pkgs.lib; {
		description = "AI Agent Loop Orchestrator - Terminal UI for AI coding agents";
		homepage = "https://github.com/subsy/ralph-tui";
		license = licenses.mit;
		mainProgram = "ralph-tui";
	};
}
