# zoxide - a smarter cd that learns your habits.
{ config, ... }:
{
  flake.modules.homeManager.zoxide = {
    programs.zoxide.enable = true;

    home.shellAliases = {
      cd = "z";
      cdi = "zi";
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.zoxide ];
}
