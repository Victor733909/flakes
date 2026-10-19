{
  description = "Development environment for nixdot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixdot.url = "github:barnaby0x0/nixdot";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixdot,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f rec {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);
      # nix develop --command nixdot --config ./user-config.nix
      devShells = forAllSystems (
        { system, pkgs }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.cowsay
              nixdot.packages.${system}.nixdot
            ];
          };
        }
      );
    };
}
