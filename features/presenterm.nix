# presenterm - Markdown slide decks in the terminal.
{ config, ... }:
{
  flake.modules.homeManager.presenterm =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.presenterm ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.presenterm ];
}
