# zip - create ZIP archives.
{ config, ... }:
{
  flake.modules.homeManager.zip =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.zip ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.zip ];
}
