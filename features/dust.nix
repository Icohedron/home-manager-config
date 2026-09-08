# dust - disk usage, sorted by size.
{ config, ... }:
{
  flake.modules.homeManager.dust =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.dust ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.dust ];
}
