{ pkgs, lib, ... }:

{
  programs.bash = {
    enable = true;

    shellAliases = {
      ll = "ls -lah";
    };
  };

  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;

      plugins = [
        "sudo"
      ];
    };

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      extended = true;
    };

    shellAliases = {
      dotfiles = "/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
      dotcrypt = "GIT_DIR=$HOME/.dotfiles/ GIT_WORK_TREE=$HOME git-crypt";
      cqt = "cat";
    };

    initContent = lib.mkBefore ''
      # Oh My Zsh custom directory
      export ZSH_CUSTOM="$HOME/.custom"

      # PATH
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/bin:$PATH"

      # Locale
      export LANG="fr_FR.UTF-8"
      export LC_MESSAGES="fr_FR.UTF-8"
      export LC_ALL="fr_FR.UTF-8"

      # GPG
      export GPG_TTY="$(tty)"

      # run-help
      unalias run-help 2>/dev/null
      alias help=run-help
      autoload -Uz run-help

      # Powerlevel10k
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

      # Powerlevel10k configuration
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
    '';
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
}
