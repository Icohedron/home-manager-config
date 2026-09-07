# which - locate a command on PATH.
{ config, ... }:
{
  flake.modules.homeManager.which =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.which ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.which ];
}
