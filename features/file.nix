# file - identify file types.
{ config, ... }:
{
  flake.modules.homeManager.file =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.file ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.file ];
}
