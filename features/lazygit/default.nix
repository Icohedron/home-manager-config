# lazygit - terminal UI for Git.
{ config, ... }:
{
  flake.modules.homeManager.lazygit = {
    programs.lazygit.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.lazygit ];
}
