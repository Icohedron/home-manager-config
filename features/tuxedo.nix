# tuxedo - keyboard-driven terminal UI for todo.txt.
{ config, ... }:
{
  flake.modules.homeManager.tuxedo =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.tuxedo ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.tuxedo ];
}
