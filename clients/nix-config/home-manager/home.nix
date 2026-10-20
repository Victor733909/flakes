
{ userConfig, ... }:

{
  home.username = userConfig.username;
  home.homeDirectory = userConfig.homeDirectory;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  my.user.git = {
    inherit (userConfig.git) name email;
  };
}
