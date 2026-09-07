# tuicr - terminal code review UI.
#
# The agent-facing skill that drives tuicr from pi is built in
# ../pi-coding-agent/integrations.nix, because it is a pi extension point.
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
