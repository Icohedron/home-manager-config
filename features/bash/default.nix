# Bash, kept available as the POSIX fallback shell.
{ config, ... }:
{
  flake.modules.homeManager.bash = {
    programs.bash.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.bash ];
}
