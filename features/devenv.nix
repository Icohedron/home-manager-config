# devenv - reproducible per-project developer environments.
{ config, ... }:
{
  flake.modules.homeManager.devenv = {
    programs.devenv = {
      enable = true; # note: secretspec is also included with devenv
      # Don't use devenv shell hooks due to: https://github.com/cachix/devenv/issues/3041
      # Opt for direnv instead.
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = false;

      # In .envrc:
      # #!/usr/bin/env bash
      # eval "$(devenv direnvrc)"
      # use devenv
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.devenv ];
}
