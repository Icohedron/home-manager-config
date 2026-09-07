# mask - the maskfile.md task runner used by this repository.
{ config, ... }:
{
  flake.modules.homeManager.mask =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.mask ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.mask ];
}
