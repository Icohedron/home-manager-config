# Herdr - the terminal multiplexer every agent pane runs inside.
{ config, ... }:
{
  flake.modules.homeManager.herdr =
    { config, lib, ... }:
    let
      # herdr spawns this command for every pane it opens. Don't hardcode zsh:
      # if ../zsh is ever unregistered, the shell would not be installed and
      # herdr would quietly drop back to /bin/sh. Pick the first shell this
      # configuration actually enables instead, and if none of them is enabled,
      # leave the key out entirely so herdr keeps using $SHELL.
      preferredShell = lib.findFirst (shell: shell.enable) null [
        {
          enable = config.programs.zsh.enable;
          command = "zsh";
        }
        {
          enable = config.programs.nushell.enable;
          command = "nu";
        }
        {
          enable = config.programs.bash.enable;
          command = "bash";
        }
      ];
    in
    {
      programs.herdr = {
        enable = true;
        settings = {
          onboarding = false;
          session.resume_agents_on_restore = true;
        }
        // lib.optionalAttrs (preferredShell != null) {
          terminal.default_shell = preferredShell.command;
        };
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.herdr ];
}
