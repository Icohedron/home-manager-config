# nixfmt - the official Nix formatter.
{ config, ... }:
{
  flake.modules.homeManager.nixfmt =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.nixfmt ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.nixfmt ];
}
