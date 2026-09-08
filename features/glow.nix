# glow - render Markdown in the terminal.
{ config, ... }:
{
  flake.modules.homeManager.glow =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.glow ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.glow ];
}
