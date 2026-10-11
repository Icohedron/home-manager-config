# tuicr - terminal code review UI.
#
# Pi and OMP build their release-matched agent skills with ./_skill.nix.
{ config, ... }:
{
  flake.modules.homeManager.tuicr =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.tuicr ];

      xdg.configFile."tuicr/config.toml".source = ./config.toml;
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.tuicr ];
}
