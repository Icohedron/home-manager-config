# gh - GitHub CLI.
{ config, ... }:
{
  flake.modules.homeManager.gh = {
    programs.gh.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.gh ];
}
