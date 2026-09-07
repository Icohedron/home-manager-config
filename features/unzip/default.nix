# unzip - extract ZIP archives.
{ config, ... }:
{
  flake.modules.homeManager.unzip =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.unzip ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.unzip ];
}
