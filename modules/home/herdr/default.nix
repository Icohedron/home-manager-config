# Herdr: terminal workspace/agent multiplexer (https://herdr.dev).
#
# This file owns herdr itself; ./plugins holds one file per herdr plugin, each
# self-contained. The pi integration herdr needs to detect Pi Coding Agent lives
# in ../agent-tools.nix, next to the rest of the Pi configuration.
{ ... }:
{
  imports = [
    ./plugins/command-palette.nix
    ./plugins/reviewr.nix
  ];

  # Config is rendered to ~/.config/herdr/config.toml by Home Manager.
  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;
      terminal.default_shell = "zsh";
      session.resume_agents_on_restore = true;

      # Plugin keybindings live here rather than in the plugin modules: herdr
      # takes them as one `[[keys.command]]` list, which two modules cannot each
      # define. Keys are checked against `herdr --default-config`; `prefix+d` and
      # `prefix+a` are unbound there. Note that herdr does not report a clash, so
      # reusing a default key silently shadows one of the two.
      keys.command = [
        {
          key = "prefix+d";
          type = "plugin_action";
          command = "persiyanov.reviewr.toggle";
          description = "reviewr: toggle pane";
        }
        {
          key = "prefix+a";
          type = "plugin_action";
          command = "jt.command-palette.open";
          description = "Command palette";
        }
      ];
    };
  };
}
