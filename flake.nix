{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    # elm-format is broken on recent nixpkgs: https://github.com/NixOS/nixpkgs/issues/370084
    elm-nixpkgs.url = "github:NixOS/nixpkgs/7e2fb8e0eb807e139d42b05bf8e28da122396bed";
  };

  outputs = {
    self,
    nixpkgs,
    elm-nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
          elm-pkgs = import elm-nixpkgs {inherit system;};
        });
  in {
    devShells = forEachSupportedSystem ({
      pkgs,
      elm-pkgs,
    }: {
      default = pkgs.mkShell {
        buildInputs = [
          # Elm
          elm-pkgs.elmPackages.elm
          elm-pkgs.elmPackages.elm-format
          elm-pkgs.elmPackages.elm-test-rs
          elm-pkgs.elmPackages.elm-json
          elm-pkgs.elmPackages.elm-language-server
          elm-pkgs.elm2nix

          # JS
          pkgs.nodejs_22
          pkgs.typescript

          # Nix
          pkgs.alejandra

          # Scripts
          pkgs.just

          # Tailwind
          pkgs.rustywind
          pkgs.tailwindcss_4
        ];
        shellHook = ''
          npm install
          export PATH="$PWD/node_modules/.bin/:$PATH"
        '';
      };
    });
  };
}
