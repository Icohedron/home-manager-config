{
  description = "Dendritic Home Manager configuration built with flake-parts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # =========================================================================
  # DENDRITIC PATTERN
  # =========================================================================
  # Every *.nix file below ./system and ./features is a flake-parts module,
  # imported automatically by import-tree. There is no central list of imports
  # to maintain: dropping a file into ./features/ is enough to add it.
  #
  #   ./system   - machine/system configuration and hardware-specific packages
  #   ./features - one self-contained file (or directory) per program
  #
  # Files whose path contains "/_" are ignored by import-tree, so helper data
  # can live next to a feature without being evaluated as a module.
  # =========================================================================
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Provides `flake.modules.<class>.<name>`, the option every feature
        # publishes itself through.
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree [
          ./system
          ./features
        ])
      ];
    };
}
