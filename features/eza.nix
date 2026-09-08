# eza - a modern replacement for ls.
{ config, ... }:
{
  flake.modules.homeManager.eza = {
    programs.eza.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.eza ];
}
