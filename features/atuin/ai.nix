# The self-hosted Atuin AI backend, and the local model behind it.
#
# Two user services, both bound to loopback:
#
#   atuin-ai-model    llama.cpp serving a small tool-calling model
#   atuin-ai-server   atuin-ai-server, the OSS Atuin AI backend
#
# atuin-ai-server (https://github.com/atuinsh/atuin-ai-server) is the same
# engine the hosted service runs, without accounts, database or usage limits;
# it translates the Atuin AI protocol into plain OpenAI chat completions. It
# ships only as a container image, hence podman rather than a package.
#
# ./default.nix points the Atuin CLI at it; ./_ai-stack.nix decides whether any
# of this is built (`user.atuinAI`) and holds the ports, the host-loopback
# address and the model both files agree on.
{ config, lib, ... }:
let
  aiStack = import ./_ai-stack.nix { inherit config; };

  atuinAI = config.flake.modules.homeManager.atuin-ai;
in
{
  flake.modules.homeManager.atuin-ai =
    { pkgs, ... }:
    let
      # The build that matches this machine's GPU stack, from
      # ../llama-cpp.nix - the feature that owns that choice.
      llamaCpp = config.flake.lib.llamaCppFor pkgs;

      podman = lib.getExe pkgs.podman;

      image = "ghcr.io/atuinsh/atuin-ai-server:latest";
      containerName = "atuin-ai-server";

      # Operator config for atuin-ai-server, read from CHAT_CONFIG (the image
      # defaults it to /etc/atuin-ai/config.toml).
      serverConfig = (pkgs.formats.toml { }).generate "atuin-ai-server.toml" {
        port = aiStack.serverPort;

        # The OpenAI-compatible endpoint to translate to: the llama.cpp server
        # below, reached on the host's loopback interface.
        endpoint = "http://${aiStack.hostLoopback}:${toString aiStack.modelPort}/v1";

        default_model = aiStack.model.alias;

        # llama.cpp, like most engines, only reports token usage on a stream
        # when it is asked to.
        request.body.stream_options.include_usage = true;

        models = [
          {
            alias = aiStack.model.alias;
            name = aiStack.model.displayName;
            description = aiStack.model.description;
            model = aiStack.model.alias;
          }
        ];

        # No [web_tools]: those need Brave and Firecrawl API keys, and a
        # local-only assistant has no business calling them.
        #
        # No api_key either - llama.cpp wants none, and without one the server
        # sends no Authorization header at all.
      };

      llamaServerArgs = [
        "--hf-repo"
        aiStack.model.repo
        "--alias"
        aiStack.model.alias

        # Loopback only. The container reaches this through pasta's
        # --map-host-loopback, so nothing is exposed to the network.
        "--host"
        "127.0.0.1"
        "--port"
        (toString aiStack.modelPort)

        "--ctx-size"
        (toString aiStack.model.contextSize)

        # Tool calling is driven by the model's own chat template, which needs
        # the jinja engine. It is the default in current llama.cpp; say it
        # anyway, because Atuin AI is unusable without tools. llama.cpp
        # recognises MiniCPM5's XML calls
        # (<function name="..."><param name="...">) and hands back ordinary
        # OpenAI tool_calls.
        "--jinja"

        # MiniCPM5 thinks by default, and Atuin AI has nowhere to put that:
        # atuin-ai-core drops reasoning deltas on the floor ("no wire events
        # exist for these yet" - http/driver.gleam), and its prompt asks the
        # model to explain itself in plain text instead. `off` fills in the
        # empty <think></think> block the template expects, so no time is
        # spent on tokens the CLI would never show. The "thinking" status the
        # backend streams is just a spinner label, not reasoning.
        "--reasoning"
        "off"
      ]
      ++ lib.concatLists (
        lib.mapAttrsToList (flag: value: [
          "--${flag}"
          value
        ]) aiStack.model.sampling
      );

      podmanRunArgs = [
        "run"
        "--rm"
        # Take over a container left behind by an unclean stop.
        "--replace"
        "--name"
        containerName

        # Ask pasta - podman's rootless network default - to forward this
        # link-local address to the host's 127.0.0.1, where atuin-ai-model
        # listens. Podman's own host.containers.internal is no use here: it
        # maps to the host's *external* address, which would force llama.cpp
        # to listen on a routable one.
        "--network=pasta:--map-host-loopback,${aiStack.hostLoopback}"

        # Reachable from this machine only: with no AUTH_TOKEN set, whoever
        # reaches the port gets to spend the model's time.
        "--publish"
        "127.0.0.1:${toString aiStack.serverPort}:${toString aiStack.serverPort}"

        "--volume"
        "${serverConfig}:/etc/atuin-ai/config.toml:ro"

        image
      ];
    in
    {
      systemd.user.services.atuin-ai-model = {
        Unit = {
          Description = "llama.cpp server for Atuin AI (${aiStack.model.displayName})";
          Documentation = [ "https://github.com/ggml-org/llama.cpp" ];
          # Weights are fetched from Hugging Face on the first start.
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          ExecStart = "${llamaCpp}/bin/llama-server ${lib.escapeShellArgs llamaServerArgs}";

          # Under WSL2 the GPU driver lives outside the usual search path, and
          # Nix's glibc ignores /etc/ld.so.cache. Naming a directory that does
          # not exist is a no-op everywhere else.
          Environment = [ "LD_LIBRARY_PATH=/usr/lib/wsl/lib" ];

          Restart = "on-failure";
          RestartSec = 10;
        };

        Install.WantedBy = [ "default.target" ];
      };

      # Written by hand rather than through `services.podman.containers`:
      # Home Manager builds every quadlet during evaluation (it reads the
      # generated unit directory back with builtins.readDir), and that import
      # from derivation cannot be evaluated for the other platform in
      # `systems`, which would break `nix flake check`. The container is a
      # single foreground process, so a unit costs nothing else.
      systemd.user.services.atuin-ai-server = {
        Unit = {
          Description = "Self-hosted Atuin AI backend";
          Documentation = [ "https://docs.atuin.sh/ai/self-hosting/" ];
          # The backend is useless without the model, and starting the pair
          # together is what makes `?` work right after login. Wants, not
          # Requires: a model still downloading its weights must not take the
          # backend down with it.
          Wants = [
            "network-online.target"
            "atuin-ai-model.service"
          ];
          After = [
            "network-online.target"
            "atuin-ai-model.service"
          ];
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

  # `user.atuinAI = false` leaves Atuin installed without any of this, and so
  # does a machine set to Docker: pasta and rootless podman are what the
  # backend is built on (see ../../system/hardware.nix). ./_ai-stack.nix makes
  # that call once, so the client cannot advertise a backend that was never
  # built.
  flake.modules.homeManager.workstation.imports = lib.optional aiStack.enable atuinAI;
}
