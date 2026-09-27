# uutils - unprefixed Rust coreutils, taking precedence on the user's PATH.
{ config, ... }:
{
  flake.modules.homeManager.uutils =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.uutils-coreutils-noprefix ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.uutils ];
}
