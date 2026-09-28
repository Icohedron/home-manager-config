# lazyjj - terminal UI for jj.
{ config, ... }:
{
  flake.modules.homeManager.lazyjj =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lazyjj ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.lazyjj ];
}
