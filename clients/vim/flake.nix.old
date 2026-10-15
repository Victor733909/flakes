{
  description = "Test import";
  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
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
            pkgs = nixpkgs.legacyPackages.${system};
            custom-vim = vim-config.packages.${system}.vim;
          }
        );
        # or 
        #forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forEachSystem (
        { custom-vim, ... }:
        {
          default = custom-vim;
        }
      );

      # ou
      #packages = forEachSystem (system:
      #  let
      #    pkgs = nixpkgs.legacyPackages.${system};
      #    custom-vim = vim-config.packages.${system}.vim;
      #  in
      #  {
      #    default = custom-vim;
      #  }
      #);

      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);

    };
}

