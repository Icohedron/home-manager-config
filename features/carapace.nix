# carapace - multi-shell completion engine.
{ config, ... }:
{
  flake.modules.homeManager.carapace = {
    programs.carapace.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.carapace ];
}
