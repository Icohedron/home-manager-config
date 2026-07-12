{
  description = "Nix flake for personal system configuration";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
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
      flake-utils,
      home-manager,
      llm-agents,
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
