# tirith - shell session guard/integration.
{ config, ... }:
{
  flake.modules.homeManager.tirith = {
    programs.tirith.enable = true;
    programs.tirith.enableBashIntegration = false; # known bugs with bash
    programs.tirith.enableZshIntegration = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.tirith ];
}
