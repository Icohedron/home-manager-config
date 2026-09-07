# hyperfine - command-line benchmarking tool.
{ config, ... }:
{
  flake.modules.homeManager.hyperfine =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.hyperfine ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.hyperfine ];
}
