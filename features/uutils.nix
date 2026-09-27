# uutils - Rust coreutils alongside GNU coreutils (uutils-prefixed commands).
{ config, ... }:
{
  flake.modules.homeManager.uutils =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.uutils-coreutils ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.uutils ];
}
