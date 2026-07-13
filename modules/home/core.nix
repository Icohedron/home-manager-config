# Core Home Manager and Nix settings shared by every machine/user.
{
  outputs,
  username,
  homeDirectory,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [ outputs.overlays.stable-packages ];
  nixpkgs.config.permittedInsecurePackages = [ ];
  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # For non-NixOS systems, enable generic Linux integration.
  targets.genericLinux.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Keep this pinned to the original Home Manager state version unless you are
  # intentionally adopting new defaults from a newer release.
  home.stateVersion = "25.11";

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.sessionVariables = { };
}
