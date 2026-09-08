# fastfetch - system information tool.
{ config, ... }:
{
  flake.modules.homeManager.fastfetch = {
    programs.fastfetch.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.fastfetch ];
}
