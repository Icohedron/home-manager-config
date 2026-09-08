# dotenv-cli - run a command with a .env file loaded.
{ config, ... }:
{
  flake.modules.homeManager.dotenv-cli =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.dotenv-cli ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.dotenv-cli ];
}
