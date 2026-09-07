# Nixpkgs overlays published by this flake.
{ inputs, ... }:
{
  # When applied, the stable nixpkgs set (declared in the flake inputs) is
  # accessible through 'pkgs.stable'.
  flake.overlays.stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
