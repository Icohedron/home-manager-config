# Atuin - shell history in a SQLite database, searched with ctrl-r.
#
# This is a local-only install: no Atuin Hub account, no sync server, and
# therefore no key to look after. History never leaves the machine.
#
# Atuin AI (the `?` key on an empty prompt) does not need Hub either - it is
# pointed at the self-hosted backend from ./ai.nix, which runs against a local
# model, and is switched off entirely by `user.atuinAI = false`. Everything the
# two files share lives in ./_ai-stack.nix.
{ config, lib, ... }:
let
  # Whether the backend is built, plus the ports and model it uses. Not to be
  # confused with the `ai` settings block below, which is Atuin's own `[ai]`
  # section.
  aiStack = import ./_ai-stack.nix { inherit config; };
in
{
  flake.modules.homeManager.atuin = {
    # ctrl-r belongs to Atuin now. fzf's history widget binds the same key, and
    # since Atuin's shell hook is sourced last it would win silently anyway -
    # so say which one is meant, and stop Home Manager warning about the clash.
    # fzf keeps ctrl-t (files) and alt-c (directories); see features/fzf.nix.
    programs.fzf.historyWidget.command = "";

    programs.atuin = {
      enable = true;

      # Up-arrow stays the shell's own: stepping back through this session's
      # commands, one keystroke at a time, is a different job from searching
      # everything ever run. ctrl-r (and `?`, when the AI is on) is where
      # Atuin belongs.
      #
      # Without a backend there is nothing for `?` to reach either, so drop
      # that binding rather than leave a key that only ever errors.
      flags = [
        "--disable-up-arrow"
      ]
      ++ lib.optional (!aiStack.enable) "--disable-ai";

      # Atuin rewrites ~/.config/atuin/config.toml after a shell command when
      # it finds settings missing, which leaves a real file where Home Manager
      # wants its symlink. Claim the file instead of failing the activation.
      forceOverwriteSettings = true;

      settings = {
        # No sync server: never contact one, and never ask about an account.
        # `sync_address` is left unset on purpose - it only matters once
        # `atuin login` has run against a server.
        auto_sync = false;

        # The package is updated by this flake, not by Atuin.
        update_check = false;

        ai = {
          # The `?` key binding. Off unless ./ai.nix actually built a backend
          # for it to reach.
          enabled = aiStack.enable;
        }
        // lib.optionalAttrs aiStack.enable {
          # The self-hosted backend from ./ai.nix, published on loopback only.
          endpoint = "http://127.0.0.1:${toString aiStack.serverPort}";

          # "auto" would infer this from the address, but say it outright:
          # a standalone atuin-ai-server, so no Hub login flow. `api_token`
          # stays unset, matching a server started without AUTH_TOKEN.
          endpoint_protocol = "oss";

          yolo = false;
          tips = true;

          capabilities = {
            # Reading past command *output* needs two things recording it: the
            # daemon, to hold it in memory, and pty-proxy, to capture it from
            # the terminal. Neither runs here, so do not advertise a capability
            # that can only fail.
            #
            # Both were tried (`daemon.enable`, plus `[pty_proxy] enabled`, and
            # capture did work in a plain terminal). What rules it out is
            # herdr, where nearly every shell here lives: herdr works out which
            # agent a pane is running - and whether a pane is free at all - by
            # looking at the foreground process of the PTY it gave that pane,
            # and pty-proxy has to *be* that process to read the shell's
            # OSC 133 markers. Wrap the pane and `herdr agent list` goes empty:
            # the agent panel loses every session.
            #
            # Worth revisiting only if herdr matches agents among the pane
            # process's descendants rather than its foreground process. The
            # obvious workaround does not hold: pi already reports itself
            # through `pane.report_agent` (see `herdr integration status`), and
            # behind the proxy that registration silently fails to land, even
            # though the same pane can be registered by hand with
            # `herdr pane report-agent`.
            enable_history_output = false;

            enable_history_search = true;
            enable_file_tools = true;
            enable_command_execution = true;
          };

          opening = {
            send_cwd = true;
            send_last_command = true;
          };
        };
      };
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.atuin ];
}
