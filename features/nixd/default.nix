# nixd - Nix language server with flake awareness.
{ config, ... }:
{
  flake.modules.homeManager.nixd =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.nixd ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.nixd ];
}
