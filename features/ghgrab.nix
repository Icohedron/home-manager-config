# ghgrab - download files and directories from GitHub repositories.
{ config, ... }:
{
  flake.modules.homeManager.ghgrab =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ghgrab ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.ghgrab ];
}
