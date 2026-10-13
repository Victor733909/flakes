{
  description = "Development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;

      mkVim = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.vim-full.customize {
          name = "vim";

          vimrcConfig.customRC = ''
            set number
            set relativenumber
            set syntax=on
            set tabstop=4
            set shiftwidth=4
            set expandtab

            echo "Vim configuré par Nix activé !"
          '';

          vimrcConfig.packages.monPack = with pkgs.vimPlugins; {
            start = [
              vim-airline
              ale
            ];
          };
        };
    in
    {
      packages = forEachSystem (system: {
        default = mkVim system;
        vim = mkVim system;
      });

      devShells = forEachSystem (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [
            (mkVim system)
          ];
        };
      });

      formatter = forEachSystem (
        system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style
      );
    };
}