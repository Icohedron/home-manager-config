# jq - command-line JSON processor.
{ config, ... }:
{
  flake.modules.homeManager.jq =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.jq ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.jq ];
}
