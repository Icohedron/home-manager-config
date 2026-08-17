{
  description = "Nix flake for personal system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      system = "x86_64-linux";
      # =====================================================================
      # USER CONFIGURATION
      # =====================================================================
      # Edit user.nix to match your system and personal details.
      # You may want to use `git update-index --assume-unchanged user.nix`
      # to make git assume this file remains unchanged.
      user = import ./user.nix;
      # =====================================================================
    in
    {
      overlays = import ./overlays { inherit inputs; };
      homeConfigurations = {
        ${user.username} = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit
              inputs
              outputs
              ;
            inherit (user)
              username
              gitUsername
              gitEmail
              ;
            homeDirectory = user.homeDirectory or "/home/${user.username}";
            useWayland = user.useWayland or true;
            llamaCppGPUBackend = user.llamaCppGPUBackend or "vulkan";
            npmRegistry = user.npmRegistry or "https://registry.npmjs.org/";
            pypiRegistry = user.pypiRegistry or "https://pypi.org/simple/";
            nugetRegistry = user.nugetRegistry or "https://api.nuget.org/v3/index.json";
          };
          modules = [
            ./home.nix
          ];
        };
      };
    };
}
