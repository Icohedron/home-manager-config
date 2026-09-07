# tree - recursive directory listings.
{ config, ... }:
{
  flake.modules.homeManager.tree =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.tree ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.tree ];
}
