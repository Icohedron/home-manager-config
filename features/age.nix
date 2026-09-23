# age - simple, modern, and secure file encryption.
{ config, ... }:
{
  flake.modules.homeManager.age =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.age ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.age ];
}
