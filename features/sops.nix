# sops - encrypt and decrypt structured files with age, PGP, or cloud KMS.
{ config, ... }:
{
  flake.modules.homeManager.sops =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.sops ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.sops ];
}
