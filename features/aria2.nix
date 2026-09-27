# aria2 - command-line download manager.
{ config, ... }:
{
  flake.modules.homeManager.aria2 = {
    programs.aria2.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.aria2 ];
}
