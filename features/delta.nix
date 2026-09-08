# delta - syntax-highlighting pager for Git diffs.
#
# Enabling it here also writes the `[delta]` section of ~/.config/git/config,
# so the whole pager lives in this feature rather than in ./git.nix.
{ config, ... }:
{
  flake.modules.homeManager.delta = {
    programs.delta.enable = true;

    programs.git.settings.delta = {
      navigate = true;
      dark = true;
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.delta ];
}
