# bat - a cat clone with syntax highlighting and Git integration.
{ config, ... }:
{
  flake.modules.homeManager.bat = {
    programs.bat.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.bat ];
}
