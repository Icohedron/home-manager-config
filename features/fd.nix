# fd - a fast and user-friendly alternative to find.
{ config, ... }:
{
  flake.modules.homeManager.fd = {
    programs.fd.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.fd ];
}
