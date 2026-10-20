
{
  description = "Test client for nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-config = {
      url = "github:barnaby0x0/nix-config";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    neovim = {
      url = "github:jordanisaacs/neovim-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, nix-config, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.test =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            nix-config.homeModules.default
            ./home.nix
          ];

          extraSpecialArgs = {
            userConfig = {
              username = "user";
              homeDirectory = "/home/user";

              git = {
                name = "Test User";
                email = "user@example.com";
              };
            };
          };
        };
    };
}
