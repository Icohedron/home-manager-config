# valgrind - memory error detector (the "light" build, without GDB support).
{ config, ... }:
{
  flake.modules.homeManager.valgrind =
    { lib, pkgs, ... }:
    {
      # valgrind is marked broken on Darwin.
      home.packages = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.valgrind-light;
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.valgrind ];
}
