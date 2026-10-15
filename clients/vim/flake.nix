{
  description = "Test import";
  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:NixOs/nixpkgs/a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf";
    # nixpkgs-terraform-source.url = "github:NixOS/nixpkgs/f32fd3c0cf6f34c74814b8d2a996ee56a8508798";
    vim-config = {
      url = "github:Victor733909/flakes?dir=vim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #inputs.flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  };

  outputs =
    {
      self,
      nixpkgs,
      vim-config,
      home-manager,
      # nixpkgs-terraform-source,
      # nixpkgs-terraform,
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
            #pkgs = nixpkgs.legacyPackages.${system};
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "terraform";
            };
            custom-vim = vim-config.packages.${system}.vim;

            ## Test for another terraform version
            # pkgs-old = import nixpkgs-terraform-source {
            #   inherit system;
            #   config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "terraform";
            # };
            #custom-terraform = pkgs-old.terraform;
            # terraform-old = pkgs.symlinkJoin {
            #   name = "terraform-1.5.2";
            #   paths = [ pkgs-old.terraform ];
            #   postBuild = ''
            #     # On crée un lien symbolique nommé 'terraform15' qui pointe vers le binaire d'origine
            #     ln -s $out/bin/terraform $out/bin/terraform15
            #   '';
            # };

            # terraform-bin = nixpkgs-terraform.packages.${system}."terraform-1.15.9";

            terraform-bin =
              let
                version = "1.15.9";
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
                  hash = "sha256-cCshNq9nKMj/A3+EPdLbzit62IeGtzgdHXKu+iUPYBw=";
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
              # terraform-old
            ];

            shellHook = ''
              export ZDOTDIR=$(mktemp -d)
              trap "rm -rf $ZDOTDIR" EXIT

              cp -rL ${hm-files}/. "$ZDOTDIR"/
              chmod -R u+w "$ZDOTDIR"

              if [ -z "$ZSH_VERSION" ]; then
                echo "Welcome to your virtual Zsh + Oh My Zsh devShell!"
                exec zsh
              fi
            '';

            # shellHook = ''
            #                 # 1. Créer un dossier de configuration temporaire dans /tmp
            #                 export ZDOTDIR=$(mktemp -d)

            #                 # Nettoyage automatique du dossier /tmp à la fermeture du shell
            #                 trap "rm -rf $ZDOTDIR" EXIT

            #                 # 2. Écrire le contenu du .zshrc virtuel et temporaire
            #                 cat << 'EOF' > "$ZDOTDIR/.zshrc"
            #                 # Initialisation de Oh My Zsh
            #                 export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh/"
            #                 export ZSH_THEME="robbyrussell"
            #                 plugins=(git sudo)

            #                 if [ -f "$ZSH/oh-my-zsh.sh" ]; then
            #                   source "$ZSH/oh-my-zsh.sh"
            #                 fi

            #                 # Vos alias ou configurations virtuelles personnalisées ici
            #                 alias ll="ls -la"
            #                 echo "Welcome to your virtual Zsh + Oh My Zsh devShell!"
            #   EOF

            #                 # 3. Empêcher l'erreur sous Bash et forcer l'usage de Zsh
            #                 if [ -z "$ZSH_VERSION" ]; then
            #                   echo "Nix a démarré sous Bash. Bascule automatique vers Zsh..."
            #                   exec zsh
            #                 fi
            # '';

          };
        }
      );

      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);

    };
}
