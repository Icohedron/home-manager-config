# btop - resource monitor.
{ config, ... }:
{
  flake.modules.homeManager.btop = {
    programs.btop.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.btop ];
}
