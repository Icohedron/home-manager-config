# kew - command-line music player.
{ config, ... }:
{
  flake.modules.homeManager.kew =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.kew ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.kew ];
}
