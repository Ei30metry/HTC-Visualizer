{
  description = "Proof-tree visualizer for HTC's derivations";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

      in
      {
        packages.default = pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "htc-visualizer";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = with pkgs; [
            nodejs
            pkgs.pnpm.configHook
          ];
          pnpmDeps = pkgs.pnpm.fetchDeps {
            inherit (finalAttrs) pname version src;
            hash = "sha256-Y8V8hErYEJshzFcNkmlEse9BNsBF9zmtC8DJoMDgIkI=";
            fetcherVersion = 1;
          };
          buildPhase = ''
            runHook preBuild
            pnpm build
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            cp -r dist $out
            runHook postInstall
          '';
        });

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            typescript
            nodejs
            pnpm
            typescript-language-server
            vue-language-server
          ];
        };
      }
    );
}
