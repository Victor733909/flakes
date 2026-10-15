{
  description = "Test import";
  inputs = {
    #nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOs/nixpkgs/a033e66ab94a6bedf2c3d58d93a36319d3cbbbaf";
    vim-config = {
      url = "github:Victor733909/flakes?dir=vim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #inputs.flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      vim-config,
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
        { system, pkgs, custom-vim, ... }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              custom-vim
              zsh
              oh-my-zsh
              terraform
            ];

            shellHook = ''
              
                            # 1. Créer un dossier de configuration temporaire dans /tmp
                            export ZDOTDIR=$(mktemp -d)
                            
                            # Nettoyage automatique du dossier /tmp à la fermeture du shell
                            trap "rm -rf $ZDOTDIR" EXIT

                            # 2. Écrire le contenu du .zshrc virtuel et temporaire
                            cat << 'EOF' > "$ZDOTDIR/.zshrc"
                            # Initialisation de Oh My Zsh
                            export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh/"
                            export ZSH_THEME="robbyrussell"
                            plugins=(git sudo)
                            
                            if [ -f "$ZSH/oh-my-zsh.sh" ]; then
                              source "$ZSH/oh-my-zsh.sh"
                            fi

                            # Vos alias ou configurations virtuelles personnalisées ici
                            alias ll="ls -la"
                            echo "Welcome to your virtual Zsh + Oh My Zsh devShell!"
              EOF

                            # 3. Empêcher l'erreur sous Bash et forcer l'usage de Zsh
                            if [ -z "$ZSH_VERSION" ]; then
                              echo "Nix a démarré sous Bash. Bascule automatique vers Zsh..."
                              exec zsh
                            fi
            '';

          };
        }
      );

      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);

    };
}
