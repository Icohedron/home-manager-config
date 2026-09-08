# draw.io - diagram editor, also the backend of pi's pi-drawio extension.
{ config, ... }:
{
  flake.modules.homeManager.drawio =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.drawio ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.drawio ];
}
