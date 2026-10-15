{
  description = "Development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;

      mkVim =
        system:
        let
          # pkgs = nixpkgs.legacyPackages.${system};
          pkgs = import nixpkgs {
            inherit system;

            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "vim-yaml"
              ];
          };
        in
        pkgs.vim-full.customize {
          name = "vim";
          vimrcConfig.customRC = builtins.readFile ./vimrc;

          vimrcConfig.packages.myPlugins = with pkgs.vimPlugins; {
            start = [
              # Theme
              onedark-vim

              # Navigation / UI
              nerdtree
              nerdtree-git-plugin
              vim-devicons
              vim-nerdtree-syntax-highlight
              goyo-vim

              # Editing
              nerdcommenter

              # Git
              vim-gitgutter

              # Languages / formats
              vim-markdown
              nginx-vim
              vim-terraform
              vim-toml
              vim-vagrant
              vim-yaml

              # Encryption
              vim-gnupg
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

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
