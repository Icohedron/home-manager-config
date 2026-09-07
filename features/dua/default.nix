# dua - interactive disk usage analyzer.
{ config, ... }:
{
  flake.modules.homeManager.dua =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.dua ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.dua ];
}
