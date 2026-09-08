# yazi - terminal file manager.
{ config, ... }:
{
  flake.modules.homeManager.yazi = {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.yazi ];
}
