{
  description = "Reusable Zsh configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    lib.mkZshConfig = pkgs: {
      theme = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";

      aliases = {
        dotfiles = "/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
        dotcrypt = "GIT_DIR=$HOME/.dotfiles/ GIT_WORK_TREE=$HOME git-crypt";
        cqt = "cat";
      };

      historySize = 10000;
    };

    homeManagerModules.default = import ../modules/shell.nix;
  };
}