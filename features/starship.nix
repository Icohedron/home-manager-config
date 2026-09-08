# starship - cross-shell prompt.
{ config, ... }:
{
  flake.modules.homeManager.starship = {
    programs.starship.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.starship ];
}
