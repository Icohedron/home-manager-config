# devcontainer - reference CLI for running and managing devcontainer.json environments.
{ config, ... }:
{
  flake.modules.homeManager.devcontainer =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.devcontainer ];
    };

  flake.modules.homeManager.workstation.imports = [
    config.flake.modules.homeManager.devcontainer
  ];
}
