# nil - Nix language server.
{ config, ... }:
{
  flake.modules.homeManager.nil =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.nil ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.nil ];
}
