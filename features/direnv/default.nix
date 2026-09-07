# direnv - per-directory environments, wired to nix-direnv.
{ config, ... }:
{
  flake.modules.homeManager.direnv = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.direnv ];
}
