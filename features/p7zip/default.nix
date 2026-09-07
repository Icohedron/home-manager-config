# p7zip - 7-Zip archiver (7z).
{ config, ... }:
{
  flake.modules.homeManager.p7zip =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.p7zip ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.p7zip ];
}
