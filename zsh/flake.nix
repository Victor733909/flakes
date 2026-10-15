
{
  description = "Reusable shell configuration";

  outputs = { self, ... }: {
    # Interface Home Manager
    homeManagerModules.default = import ./shell.nix;

    # Interface devShell
    lib.mkZshConfig = pkgs:
      pkgs.writeTextDir ".zshrc" ''
        export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh"
        export ZSH_CUSTOM="$HOME/.custom"

        export PATH="$HOME/.local/bin:$PATH"
        export PATH="$HOME/bin:$PATH"

        export LANG="fr_FR.UTF-8"
        export LC_MESSAGES="fr_FR.UTF-8"
        export LC_ALL="fr_FR.UTF-8"

        export GPG_TTY="$(tty)"

        source "$ZSH/oh-my-zsh.sh"

        unalias run-help 2>/dev/null
        alias help=run-help
        autoload -Uz run-help

        alias dotfiles="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
        alias dotcrypt="GIT_DIR=$HOME/.dotfiles/ GIT_WORK_TREE=$HOME git-crypt"
        alias cqt="cat"

        source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      '';
  };
}
