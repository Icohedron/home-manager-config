{
  description = "Nix flake for personal system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      system = "x86_64-linux";
      # =====================================================================
      # USER CONFIGURATION
      # =====================================================================
      # Edit users.nix to match your system and personal details.
      # You may want to use `git update-index --assume-unchanged users.nix`
      # to make git assume this file remains unchanged.
      users = import ./users.nix;
      # =====================================================================
    in
    {
      overlays = import ./overlays { inherit inputs; };
      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.forEach users (userConfig: {
          name = userConfig.username;
          value = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            extraSpecialArgs = {
              inherit
                inputs
                outputs
                ;
              inherit (userConfig)
                username
                homeDirectory
                gitUsername
                gitEmail
                useWayland
                ;
            };
            modules = [
              ./home.nix
            ];
          };
        })
      );
    };
}
