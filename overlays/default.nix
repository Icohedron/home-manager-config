{ inputs, ... }@args:
{
  # When applied, the stable nixpkgs set (declared in the flake inputs) will be accessible through 'pkgs.stable'
  stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # Builds `pkgs.tuicr` from the upstream v0.23.1 release rather than the older
  # release packaged in nixpkgs. See ./tuicr-pin for what is pinned and why.
  tuicr-pin = import ./tuicr-pin;
}
