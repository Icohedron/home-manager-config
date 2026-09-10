# Herdr - the terminal multiplexer every agent pane runs inside.
{ config, ... }:
{
  flake.modules.homeManager.herdr =
    { config, lib, ... }:
    let
      # herdr spawns this command for every pane it opens. Don't hardcode zsh:
      # if ./zsh.nix is ever unregistered, the shell would not be installed and
      # herdr would quietly drop back to /bin/sh. Pick the first shell this
      # configuration actually enables instead, and if none of them is enabled,
      # leave the key out entirely so herdr keeps using $SHELL.
      #
      # An absolute path, not a bare name: herdr's server does not necessarily
      # share this shell's PATH, and anything that later resolves the pane's
      # shell (portable_pty, which both herdr and atuin build their PTYs with,
      # warns and falls back to the /etc/passwd shell) gets a path it can use.
      shellPath =
        package: fallback:
        if package == null then
          # Home Manager's `package` options are nullable: a null means the
          # shell comes from outside this configuration, so there is no store
          # path to name and a bare command is the best available answer.
          fallback
        else
          lib.getExe package;

      preferredShell = lib.findFirst (shell: shell.enable) null [
        {
          enable = config.programs.zsh.enable;
          command = shellPath config.programs.zsh.package "zsh";
        }
        {
          enable = config.programs.nushell.enable;
          command = shellPath config.programs.nushell.package "nu";
        }
        {
          enable = config.programs.bash.enable;
          command = shellPath config.programs.bash.package "bash";
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
