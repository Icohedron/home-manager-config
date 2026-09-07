# fzf - command-line fuzzy finder, with shell key bindings.
{ config, ... }:
{
  flake.modules.homeManager.fzf = {
    programs.fzf.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.fzf ];
}
