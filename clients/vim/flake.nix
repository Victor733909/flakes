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
    nixdot.url = "github:barnaby0x0/nixdot";
  };

  outputs =
    {
      self,
      nixpkgs,
      vim-config,
      home-manager,
      nixdot,
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
            pkgs = import nixpkgs { inherit system; };
            custom-vim = vim-config.packages.${system}.vim;

            terraform-bin =
              let
                terraformVersion = "1.16.6";
                terraformPlatform =
                  {
                    x86_64-linux = "linux_amd64";
                    aarch64-linux = "linux_arm64";
                    x86_64-darwin = "darwin_amd64";
                    aarch64-darwin = "darwin_arm64";
                  }
                  .${system};

                terraformHash =
                  {
                    x86_64-linux = "sha256-OANLONAwljmaehJkoUVhqAKbK0lv0fFpRSZW5Tlo8bc=";
                    aarch64-linux = "sha256-p1C1oRA48WWEayZYxAyIzXBwqmemG6tDGhS6J5KOqeo=";
                    x86_64-darwin = "sha256-eUo2w/fr9sWPIInCJgaKU50XBbo1ilZ5tRZxyNx+vHs=";
                    aarch64-darwin = "sha256-heG8eKtFvcX4KnusOSnjfQcoNKWE0iWDokmNxnu2JM0=";
                  }
                  .${system};

              in
              pkgs.stdenv.mkDerivation {
                pname = "terraform";
                version = terraformVersion;
                src = pkgs.fetchurl {
                  url = "https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_${terraformPlatform}.zip";
                  hash = terraformHash;
                };

                nativeBuildInputs = [ pkgs.unzip ];
                sourceRoot = ".";
                installPhase = "install -Dm755 terraform $out/bin/terraform";
              };

            hm = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;

              modules = [
                nixdot.homeModules.shell
                nixdot.homeModules.git
                {
                  home.username = "dev";
                  home.homeDirectory = "/home/dev";
                  home.stateVersion = "25.05";
                }
              ];
            };

            hm-files =
              (home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [
                  nixdot.homeModules.shell
                  # nixdot.homeModules.git
                  {
                    home = {
                      username = "dev";
                      homeDirectory = "/home/dev";
                      stateVersion = "25.05";
                    };
                    # Evite que HISTFILE pointe vers /home/dev
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
              lolcat
              awscli2
              fortune
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
                fortune | cowsay | lolcat
                exec zsh
              fi
              export AWS_CA_BUNDLE="/usr/local/share/ca-certificates/root_ca.crt"
            '';
          };
        }
      );

      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);

    };
}
