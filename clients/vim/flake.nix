{
  description = "Test import";
  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    vim-config = {
      url = "github:Victor733909/flakes?dir=vim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      vim-config,
      home-manager,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f rec {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "terraform";
            };
            custom-vim = vim-config.packages.${system}.vim;

            terraform-bin =
              let
                version = "1.16.6";
                platform =
                  {
                    x86_64-linux = "linux_amd64";
                    aarch64-linux = "linux_arm64";
                    x86_64-darwin = "darwin_amd64";
                    aarch64-darwin = "darwin_arm64";
                  }
                  .${system};
              in
              pkgs.stdenv.mkDerivation {
                pname = "terraform";
                inherit version;
                src = pkgs.fetchurl {
                  url = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${platform}.zip";
                  hash = "sha256-p1C1oRA48WWEayZYxAyIzXBwqmemG6tDGhS6J5KOqeo=";
                };
                nativeBuildInputs = [ pkgs.unzip ];
                sourceRoot = ".";
                installPhase = "install -Dm755 terraform $out/bin/terraform";
              };

            hm-files =
              (home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [
                  ./shell.nix # ou "${shell-config}/shell.nix" si le fichier vit dans ton flake shell
                  {
                    home = {
                      username = "dev";
                      homeDirectory = "/home/dev";
                      stateVersion = "25.05";
                    };
                    # évite que HISTFILE pointe vers /home/dev
                    programs.zsh.history.path = "$HOME/.zsh_history";
                  }
                ];
              }).config.home-files;

          }
        );
    in
    {
      packages = forEachSystem (
        { custom-vim, ... }:
        {
          default = custom-vim;
        }
      );

      devShells = forEachSystem (
        {
          system,
          pkgs,
          custom-vim,
          # terraform-old,
          terraform-bin,
          hm-files,
          ...
        }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              custom-vim
              zsh
              oh-my-zsh
              terraform-bin
              qrencode
              srm
              cowsay
            ];

            #shellHook = ''
            #  export ZDOTDIR=$(mktemp -d)
            #  trap "rm -rf $ZDOTDIR" EXIT

            #  cp -rL ${hm-files}/. "$ZDOTDIR"/
            #  chmod -R u+w "$ZDOTDIR"

            #  if [ -z "$ZSH_VERSION" ]; then
            #    echo "Welcome to your virtual Zsh + Oh My Zsh devShell!"
            #    exec zsh
            #  fi
            #'';
            shellHook = ''
              export ZDOTDIR="/$HOME/hm-files"
              if [ ! -f "$ZDOTDIR/.zshrc" ] || [ "${hm-files}/.zshrc" -nt "$ZDOTDIR/.zshrc" ]; then
                echo "Syncing Home Manager configuration files..."
                cp -rL ${hm-files}/. "$ZDOTDIR"/
                chmod -R u+w "$ZDOTDIR"
              fi
              if [ -z "$ZSH_VERSION" ]; then
                echo "Welcome to your virtual Zsh + Oh My Zsh devShell!" | cowsay
                exec zsh
              fi
            '';
          };
        }
      );

      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);

    };
}
