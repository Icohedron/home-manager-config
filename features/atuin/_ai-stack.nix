# Everything ./default.nix (the client) and ./ai.nix (the backend) must agree
# on: whether the self-hosted Atuin AI stack is built at all, which engine
# answers its questions, where everything listens, and which models are
# offered.
#
# Not a module: the path contains "/_", so import-tree skips this file instead
# of evaluating it as a flake-parts module. It takes the flake-parts `config`
# because `enable` is decided by machine and user settings.
{ config }:
let
  # "copilot" or "llama-cpp" - see ../../system/settings.nix.
  backend = config.user.atuinAIBackend;

  # Port and model of the interactive llama.cpp server, from the feature that
  # owns them (../llama-cpp.nix). Only used by the llama-cpp backend.
  llamaCpp = config.flake.lib.llamaCppServer;
in
{
  # Whether to build the self-hosted backend and point Atuin at it.
  #
  # `user.atuinAI` is the switch (see ../../user.nix); the engine check is not
  # negotiable, since the backend ships only as a container image and the
  # loopback mapping it needs is a rootless-podman feature. On a Docker
  # machine Atuin is still installed, with its AI disabled rather than
  # pointed at a backend that was never built.
  enable = config.user.atuinAI && config.hardware.containerEngine == "podman";

  inherit backend;

  # Loopback port of the self-hosted Atuin AI backend (atuin-ai-server), the
  # endpoint the Atuin CLI talks to.
  serverPort = 8081;

  # Loopback port of the LiteLLM proxy that turns plain OpenAI requests into
  # GitHub Copilot ones (Copilot's own token is short-lived and has to be
  # minted from a GitHub OAuth token, which atuin-ai-server cannot do itself).
  # Unused by the llama-cpp backend, which has a server already.
  proxyPort = 8082;

  # The OpenAI-compatible port atuin-ai-server sends its chat completions to.
  upstreamPort = if backend == "copilot" then 8082 else llamaCpp.port;

  # Address at which the container reaches the *host's* loopback interface.
  #
  # atuin-ai-server runs as a container, so "localhost" in its config would be
  # the container's own loopback. Podman's rootless default (pasta) is asked
  # for this mapping with --map-host-loopback, which forwards this link-local
  # address to 127.0.0.1 on the host - so the engine behind it never has to
  # listen on a routable address. It replaces the host.docker.internal name
  # that the Atuin docs use, which podman only wires to the host's *external*
  # address.
  hostLoopback = "169.254.1.3";

  # Shared secret between atuin-ai-server and the LiteLLM proxy. Not a secret
  # in any real sense - it sits in the world-readable Nix store - but LiteLLM
  # only enforces authentication when a master key exists, and a gate that is
  # always on beats one whose default behaviour has to be trusted. The port is
  # bound to loopback either way. llama.cpp wants no key at all, and gets
  # none: without one the backend sends no Authorization header.
  proxyKey = "sk-atuin-ai-local";

  # The models Atuin AI offers. Every one must support tool calling, since the
  # chat protocol offers tools on every turn. The first is what the `?` key
  # uses unless another is picked from the model list.
  #
  # `alias` is what the CLI's model picker shows; `id` is what the engine is
  # asked for.
  models =
    if backend == "copilot" then
      # `id` is sent to Copilot verbatim, so it has to be an id this account
      # can actually use; `mask atuin models` lists them.
      #
      # One entry, and the frontier model: premium requests are not a
      # constraint here, and the same model pi codes with is the one worth
      # having on a shell prompt. Adding a second is a line in this list -
      # the CLI then offers a picker.
      [
        {
          alias = "claude-opus-5";
          id = "claude-opus-5";
          name = "Claude Opus 5";
          description = "GitHub Copilot - frontier model";
        }
      ]
    else
      # The one model the interactive llama.cpp server serves; `id` is the
      # name it answers to, which is the `-hf` string it was started with.
      [
        {
          alias = "qwen3.6-35b";
          id = llamaCpp.model.id;
          name = llamaCpp.model.name;
          description = "Local llama.cpp on port ${toString llamaCpp.port} (mask llama start)";
        }
      ];
}
