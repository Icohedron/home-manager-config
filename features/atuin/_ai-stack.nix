# Everything ./default.nix (the client) and ./ai.nix (the backend) must agree
# on: whether the self-hosted Atuin AI stack is built at all, where it listens,
# and which model serves it.
#
# Not a module: the path contains "/_", so import-tree skips this file instead
# of evaluating it as a flake-parts module. It takes the flake-parts `config`
# because `enable` is decided by machine and user settings.
{ config }:
{
  # Whether to build the self-hosted backend and point Atuin at it.
  #
  # `user.atuinAI` is the switch (see ../../user.nix); the engine check is not
  # negotiable, since the backend ships only as a container image and the
  # loopback mapping it needs is a rootless-podman feature. On a Docker
  # machine Atuin is still installed, with its AI disabled rather than
  # pointed at a backend that was never built.
  enable = config.user.atuinAI && config.hardware.containerEngine == "podman";

  # Loopback port of the self-hosted Atuin AI backend (atuin-ai-server), the
  # endpoint the Atuin CLI talks to.
  #
  # 8080 is deliberately left alone: it belongs to the interactive llama.cpp
  # server started by `mask llama start` (see ../llama-cpp.nix).
  serverPort = 8081;

  # Loopback port of the llama.cpp server dedicated to Atuin AI. Separate from
  # 8080 so the small always-on model and the big coding model can coexist.
  modelPort = 8082;

  # Address at which the container reaches the *host's* loopback interface.
  #
  # atuin-ai-server runs as a container, so "localhost" in its config would be
  # the container's own loopback. Podman's rootless default (pasta) is asked
  # for this mapping with --map-host-loopback, which forwards this link-local
  # address to 127.0.0.1 on the host - so llama.cpp never has to listen on a
  # routable address. It replaces the host.docker.internal name that the Atuin
  # docs use, which podman only wires to the host's *external* address.
  hostLoopback = "169.254.1.3";

  # The model behind Atuin AI. It must support tool calling: the chat protocol
  # offers tools on every turn.
  #
  # MiniCPM5-2B is a 2.5B dense model built for on-device use, and tool use is
  # where it stands out - BFCL v4 66.6 against 56.8 for the 4B-class Qwen3.5,
  # which is the benchmark that actually describes this workload. Two KV heads
  # (GQA 16/2) keep the cache small enough that context is nearly free, and
  # llama.cpp parses its XML tool calls natively (see ai.nix for the reasoning
  # switch that goes with it).
  model = {
    # Hugging Face repository:quantisation, fetched by llama-server on first
    # start into the Hugging Face cache - nothing is downloaded at build time.
    #
    # Q8_0 (2.68 GB) rather than Q4_K_M (1.56 GB): quantisation costs a 2B
    # model more than a 4B one, and it shows first in exactly the structured
    # tool-call output this depends on.
    repo = "openbmb/MiniCPM5-2B-GGUF:Q8_0";

    # Name llama.cpp serves the model under (--alias), which is also what
    # atuin-ai-server sends as the request's `model` field, and the alias the
    # Atuin AI model picker shows.
    alias = "minicpm5-2b";
    displayName = "MiniCPM5 2B";
    description = "Local llama.cpp - MiniCPM5 2B (Q8_0)";

    # Native context is 131072 tokens; a shell assistant needs nowhere near
    # that, and a smaller KV cache keeps the model cheap to keep running.
    contextSize = 131072;

    # What OpenBMB recommends for the MiniCPM5 series with thinking off. Their
    # thinking numbers (temp 1.0) do not apply here - see ai.nix.
    sampling = {
      temp = "0.7";
      top-p = "0.95";
    };
  };
}
