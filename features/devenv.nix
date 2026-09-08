{ config, ... }:
{
  flake.modules.homeManager.devenv = {
    programs.devenv = {
      enable = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.devenv ];
}

