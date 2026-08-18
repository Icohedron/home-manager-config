{ inputs, ... }@args:
{
  # When applied, the stable nixpkgs set (declared in the flake inputs) will be accessible through 'pkgs.stable'
  stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # Builds `pkgs.tuicr` from the source of agavra/tuicr#600 rather than the
  # release packaged in nixpkgs. See ./tuicr-pr600 for what is pinned and why.
  tuicr-pr600 = import ./tuicr-pr600;
}
