{
  description = "Nix flake for personal system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Upstream tirith: nixpkgs pins an older release (0.3.1) that lacks the
    # bash enter-mode capability self-test (issue #111). Track upstream so the
    # hook can prove whether bind-x Enter delivery works on this bash build.
    tirith = {
      url = "github:sheeki03/tirith";
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
              homeDirectory
              gitUsername
              gitEmail
              useWayland
              npmRegistry
              ;
          };
          modules = [
            ./home.nix
          ];
        };
      };
    };
}
