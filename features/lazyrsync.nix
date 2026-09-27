# lazyrsync - terminal UI for rsync.
{ config, ... }:
{
  flake.modules.homeManager.lazyrsync =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lazyrsync ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.lazyrsync ];
}
