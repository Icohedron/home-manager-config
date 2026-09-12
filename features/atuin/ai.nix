# The self-hosted Atuin AI backend, and whatever answers its questions.
#
# User services, all bound to loopback:
#
#   atuin-ai-server   atuin-ai-server, the OSS Atuin AI backend
#   atuin-ai-proxy    LiteLLM, translating OpenAI requests to GitHub Copilot
#                     (`user.atuinAIBackend = "copilot"` only)
#
# With `user.atuinAIBackend = "llama-cpp"` there is no proxy and no second
# model: the backend points straight at the interactive llama.cpp server from
# ../llama-cpp.nix, the one `mask llama start` brings up. Nothing starts that
# server on our behalf, so `?` answers only while it runs.
#
# atuin-ai-server (https://github.com/atuinsh/atuin-ai-server) is the same
# engine the hosted service runs, without accounts, database or usage limits;
# it translates the Atuin AI protocol into plain OpenAI chat completions. It
# ships only as a container image, hence podman rather than a package.
#
# Copilot needs the proxy: atuin-ai-server cannot reach it directly, because
# Copilot's API wants a token that expires after about half an hour and has to
# be minted from a GitHub OAuth token, while atuin-ai-server resolves its
# api_key once, at boot. LiteLLM owns that refresh, so the backend sees an
# ordinary OpenAI endpoint.
#
# ./default.nix points the Atuin CLI at it; ./_ai-stack.nix decides whether any
# of this is built (`user.atuinAI`) and holds the ports, the host-loopback
# address and the models both files agree on.
{ config, lib, ... }:
let
  aiStack = import ./_ai-stack.nix { inherit config; };

  copilot = aiStack.backend == "copilot";

  atuinAI = config.flake.modules.homeManager.atuin-ai;
in
{
  flake.modules.homeManager.atuin-ai =
    { pkgs, ... }:
    let
      podman = lib.getExe pkgs.podman;

      image = "ghcr.io/atuinsh/atuin-ai-server:latest";
      containerName = "atuin-ai-server";

      # LiteLLM twice over, from one derivation: the packaged wrapper for the
      # proxy, and a plain environment for the login helper.
      #
      # `bin/litellm` is wrapped with litellm's `proxy` extras (prisma,
      # websockets and friends), which the proxy server imports at startup and
      # which a `python3.withPackages [ litellm ]` environment does not carry -
      # that env fails with `Missing dependency No module named 'websockets'`.
      # The helper below needs the opposite: a `python` that can import the
      # library, which the wrapper does not provide.
      litellm = pkgs.litellm;
      litellmPython = pkgs.python3.withPackages (ps: [ ps.litellm ]);

      # Where LiteLLM keeps the GitHub OAuth token it was granted, and the
      # short-lived Copilot token it mints from it. The default path its
      # Authenticator uses; named here so the unit and `atuin-ai-login` agree
      # even if XDG variables differ.
      copilotTokenDir = "${config.user.homeDirectory}/.config/litellm/github_copilot";

      # Interactive first-run login: GitHub's device flow, which prints a URL
      # and a code to the terminal and waits for the browser. Run once; the
      # service refreshes everything else on its own.
      atuinAILogin = pkgs.writeShellApplication {
        name = "atuin-ai-login";
        runtimeInputs = [ litellmPython ];
        text = ''
          export GITHUB_COPILOT_TOKEN_DIR=${lib.escapeShellArg copilotTokenDir}
          python - <<'PY'
          from litellm.llms.github_copilot.authenticator import Authenticator

          # get_api_key() runs the device flow when no token is stored yet,
          # then exchanges it for a Copilot token - which also proves the
          # account actually has Copilot access.
          Authenticator().get_api_key()
          print("Atuin AI: GitHub Copilot authenticated.")
          PY
          systemctl --user restart atuin-ai-proxy.service
          echo "Atuin AI: proxy restarted. Press ? on an empty prompt to chat."
        '';
      };

      # LiteLLM proxy config: one entry per model in ./_ai-stack.nix, all of
      # them through the github_copilot provider.
      proxyConfig = (pkgs.formats.yaml { }).generate "atuin-ai-litellm.yaml" {
        model_list = map (model: {
          model_name = model.id;
          litellm_params.model = "github_copilot/${model.id}";
        }) aiStack.models;

        litellm_settings = {
          # LiteLLM rewrites system messages to assistant ones for Copilot by
          # default, a workaround for models that once rejected them. Atuin's
          # entire behaviour - its tools, its output rules - is a system
          # prompt, and it is worth far more as one.
          disable_copilot_system_to_assistant = true;

          # Silently drop request fields Copilot does not accept rather than
          # failing the chat. atuin-ai-server sends a small, ordinary body,
          # but it is the CLI that would show the error.
          drop_params = true;

          # Nothing here needs to phone home.
          telemetry = false;
        };

        general_settings = {
          # Turns LiteLLM's auth on (see aiStack.proxyKey): without a master
          # key it serves whoever reaches the port.
          master_key = aiStack.proxyKey;
        };
      };

      proxyArgs = [
        "--config"
        "${proxyConfig}"

        # Loopback only. The container reaches this through pasta's
        # --map-host-loopback, so nothing is exposed to the network.
        "--host"
        "127.0.0.1"
        "--port"
        (toString aiStack.proxyPort)
      ];

      # Operator config for atuin-ai-server, read from CHAT_CONFIG (the image
      # defaults it to /etc/atuin-ai/config.toml).
      serverConfig = (pkgs.formats.toml { }).generate "atuin-ai-server.toml" (
        {
          port = aiStack.serverPort;

          # The OpenAI-compatible endpoint to translate to - the LiteLLM proxy
          # below, or the llama.cpp server - reached on the host's loopback
          # interface.
          endpoint = "http://${aiStack.hostLoopback}:${toString aiStack.upstreamPort}/v1";

          # The first entry: what `?` uses unless another is picked.
          default_model = (builtins.head aiStack.models).alias;

          # LiteLLM and llama.cpp, like most engines, only report token usage on
          # a stream when asked to.
          request.body.stream_options.include_usage = true;

          models = map (model: {
            inherit (model) alias name description;
            model = model.id;
          }) aiStack.models;

          # No [web_tools]: those need Brave and Firecrawl API keys, and the
          # models here can already read the shell's own world.
        }
        // lib.optionalAttrs copilot {
          # Matches the LiteLLM master key. llama.cpp is left keyless, and with
          # no api_key the backend sends no Authorization header at all.
          api_key = aiStack.proxyKey;
        }
      );

      podmanRunArgs = [
        "run"
        "--rm"
        # Take over a container left behind by an unclean stop.
        "--replace"
        "--name"
        containerName

        # Ask pasta - podman's rootless network default - to forward this
        # link-local address to the host's 127.0.0.1, where atuin-ai-proxy
        # listens. Podman's own host.containers.internal is no use here: it
        # maps to the host's *external* address, which would force LiteLLM
        # to listen on a routable one.
        "--network=pasta:--map-host-loopback,${aiStack.hostLoopback}"

        # Reachable from this machine only: with no AUTH_TOKEN set, whoever
        # reaches the port gets to spend this account's Copilot quota.
        "--publish"
        "127.0.0.1:${toString aiStack.serverPort}:${toString aiStack.serverPort}"

        "--volume"
        "${serverConfig}:/etc/atuin-ai/config.toml:ro"

        image
      ];
    in
    {
      home.packages = lib.optional copilot atuinAILogin;

      systemd.user.services =
        lib.optionalAttrs copilot {
          atuin-ai-proxy = {
            Unit = {
              Description = "LiteLLM proxy serving GitHub Copilot to Atuin AI";
              Documentation = [ "https://docs.litellm.ai/docs/providers/github_copilot" ];
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };

            Service = {
              ExecStart = "${litellm}/bin/litellm ${lib.escapeShellArgs proxyArgs}";

              Environment = [ "GITHUB_COPILOT_TOKEN_DIR=${copilotTokenDir}" ];

              # With no stored GitHub token LiteLLM starts the device flow at boot,
              # prints the code to the journal and gives up after a minute. Run
              # `atuin-ai-login` once instead of racing it; until then this unit
              # restarts, slowly, rather than spinning.
              Restart = "on-failure";
              RestartSec = 60;
            };

            Install.WantedBy = [ "default.target" ];
          };
        }
        // {
          # Written by hand rather than through `services.podman.containers`:
          # Home Manager builds every quadlet during evaluation (it reads the
          # generated unit directory back with builtins.readDir), and that
          # import from derivation cannot be evaluated for the other platform in
          # `systems`, which would break `nix flake check`. The container is a
          # single foreground process, so a unit costs nothing else.
          atuin-ai-server = {
            Unit = {
              Description = "Self-hosted Atuin AI backend";
              Documentation = [ "https://docs.atuin.sh/ai/self-hosting/" ];
              # The backend is useless without the engine behind it, and starting
              # the pair together is what makes `?` work right after login. Wants,
              # not Requires: a proxy still waiting to be authenticated must not
              # take the backend down with it. Nothing is said about llama.cpp -
              # that server is started by hand.
              Wants = [ "network-online.target" ] ++ lib.optional copilot "atuin-ai-proxy.service";
              After = [ "network-online.target" ] ++ lib.optional copilot "atuin-ai-proxy.service";
            };

            Service = {
              # Rootless podman calls newuidmap/newgidmap, which are setuid and so
              # cannot come from the Nix store; the distribution's copy has to be
              # found on PATH (Ubuntu and friends: `apt install uidmap`). These are
              # the locations Home Manager's own podman units search.
              Environment = [ "PATH=/run/wrappers/bin:/usr/bin:/bin:/usr/sbin:/sbin" ];

              # The image is pulled on the first start and then kept; `podman pull`
              # is what updates it, since upstream publishes only :latest.
              ExecStart = "${podman} ${lib.escapeShellArgs podmanRunArgs}";
              ExecStop = "${podman} stop --ignore --time 10 ${containerName}";
              ExecStopPost = "-${podman} rm --force --ignore ${containerName}";

              Restart = "on-failure";
              RestartSec = 10;
              TimeoutStopSec = 30;
            };

            Install.WantedBy = [ "default.target" ];
          };
        };
    };

  # `user.atuinAI = false` leaves Atuin installed without any of this, and so
  # does a machine set to Docker: pasta and rootless podman are what the
  # backend is built on (see ../../system/hardware.nix). ./_ai-stack.nix makes
  # that call once, so the client cannot advertise a backend that was never
  # built.
  flake.modules.homeManager.workstation.imports = lib.optional aiStack.enable atuinAI;
}
