# The package sets this flake evaluates against.
#
# `systems` lists the platforms this configuration can be built for. It is not
# a statement about the machine you are on: ./configurations.nix builds one home
# configuration per entry, and the right one is selected at build time.
{ inputs, ... }:
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };
}
