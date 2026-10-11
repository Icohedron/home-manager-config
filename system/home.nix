# Core Home Manager and Nix settings shared by every feature.
{ config, ... }:
{
  flake.modules.homeManager.core =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        config.flake.overlays.stable-packages
      ];
      nixpkgs.config.permittedInsecurePackages = [ ];
      nixpkgs.config.allowUnfree = true;

      nix = {
        package = pkgs.nix;
        settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      # Generic Linux integration is for non-NixOS Linux hosts only.
      targets.genericLinux.enable = pkgs.stdenv.hostPlatform.isLinux && !config.user.isNixOS;

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # Keep this pinned to the original Home Manager state version unless you
      # are intentionally adopting new defaults from a newer release.
      home.stateVersion = "25.11";

      home.username = config.user.username;
      home.homeDirectory = config.user.homeDirectory;
      home.sessionVariables = { };
    };
}
