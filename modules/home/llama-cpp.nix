# Local llama.cpp inference server.
#
# `llama-server` runs in *router* mode (started without `--model`) as a user
# service. The router exposes an OpenAI-compatible API on a single port and
# loads/unloads the models it knows about on demand.
#
# Models are declared in an INI preset file (`--models-preset`), where each
# section becomes a router-visible model id and each key is a `llama-server`
# command line flag without the leading dashes. This file also registers the
# resulting model with Pi Coding Agent so it shows up in `/model`; the rest of
# the Pi configuration lives in ./agent-tools.nix.
{
  lib,
  pkgs,
  homeDirectory,
  ...
}:
let
  # ---------------------------------------------------------------------------
  # Server
  # ---------------------------------------------------------------------------
  # The Vulkan build drives the RDNA3 dGPU through Mesa's RADV driver and falls
  # back to CPU-only inference when no Vulkan device is visible (which is the
  # case inside containers that do not pass through /dev/dri).
  package = pkgs.llama-cpp-vulkan;

  host = "127.0.0.1";
  port = 8080;
  serverUrl = "http://${host}:${toString port}";

  # Weights pulled with `hf-repo` are cached here. llama.cpp creates this
  # directory itself on first download, so nothing needs to pre-create it.
  cacheDir = "${homeDirectory}/.cache/llama.cpp";

  # ---------------------------------------------------------------------------
  # Models
  # ---------------------------------------------------------------------------
  # Sized against a 12 GB VRAM budget. Roughly 91% of Qwen3.6-35B-A3B is MoE
  # expert weight, so no quantization of it comes close to fitting in 12 GB and
  # the experts have to stream from system RAM regardless. That inverts the
  # usual tradeoff: VRAM is spent on the KV cache and the dense layers, while
  # the quantization is bounded by system RAM instead.
  qwen = {
    # Preset section name. This is the model id used by the router API, and
    # therefore also the id Pi sends in requests.
    id = "Qwen3.6-35B-A3B";
    repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
    # ~16.9 GB, of which ~5 GB ends up resident on the GPU, so ~12 GB stays in
    # RAM. A smaller quantization also speeds up the expert matmuls, which run
    # on the CPU here. UD-Q4_K_XL (~22.4 GB) is the upgrade when there is RAM
    # to spare; UD-Q2_K_XL (~12.3 GB) trades noticeable quality for speed.
    quant = "UD-Q3_K_XL";
    # 262144 tokens: the native context length of Qwen3.6. Going beyond this
    # requires YaRN rope scaling.
    contextWindow = 256 * 1024;
    # Qwen recommends 32K output for normal use and 81920 for hard problems.
    maxTokens = 81920;
  };

  modelsPreset = pkgs.writeText "llama-models.ini" ''
    version = 1

    ; Defaults inherited by every model the router knows about.
    [*]
    ; Required for the model's own chat template and its tool calling format.
    jinja = true

    [${qwen.id}]
    hf-repo = ${qwen.repo}:${qwen.quant}
    ; Setting the context size explicitly is load-bearing beyond just asking for
    ; 256K: llama.cpp only auto-shrinks the context to fit VRAM when it was left
    ; unset (see the n_ctx == 0 branch in common/fit.cpp). Pinning it forces
    ; --fit to overflow MoE expert tensors to system RAM instead of quietly
    ; handing back a 4096-token window on a 12 GB card.
    ctx-size = ${toString qwen.contextWindow}
    ; n-gpu-layers is left at its default of `auto`, which runs that fitting and
    ; keeps as many experts on the GPU as the budget allows.
    ;
    ; A q8_0 KV cache roughly halves the 256K cache (~5.2 GB -> ~2.6 GB) for a
    ; negligible quality cost. Quantized KV requires flash attention. This is
    ; the single biggest VRAM lever here: every GB saved is another GB of
    ; experts that stays on the GPU.
    flash-attn = on
    cache-type-k = q8_0
    cache-type-v = q8_0
    ; Sampling defaults recommended by Qwen for thinking mode on coding tasks.
    temp = 0.6
    top-p = 0.95
    top-k = 20
    min-p = 0.0
    presence-penalty = 0.0
    ; Loading ~17 GB takes a while, so do it on first request instead of at
    ; server startup, and release the memory again after 15 idle minutes.
    load-on-startup = false
    sleep-idle-seconds = 900
  '';
in
{
  home.packages = [ package ];

  # Lets Pi's built-in llama.cpp integration (`/llama`) manage the router
  # without running `/login llama.cpp` first.
  home.sessionVariables.LLAMA_BASE_URL = serverUrl;

  systemd.user.services.llama-server = {
    Unit = {
      Description = "llama.cpp router server";
      Documentation = "https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      # No --model/--hf-repo here: that is what selects router mode. Flags
      # passed on the command line also override every preset, so per-model
      # settings belong in modelsPreset instead.
      #
      # There is no --models-dir: every model is declared in the preset and
      # pulled with `hf-repo`. Adding it back would also make the service
      # refuse to start until that directory exists.
      ExecStart = lib.concatStringsSep " " [
        "${package}/bin/llama-server"
        "--host ${host}"
        "--port ${toString port}"
        "--models-preset ${modelsPreset}"
        # A single resident model at a time; these are large enough that two
        # would not fit anyway.
        "--models-max 1"
      ];
      Environment = [ "LLAMA_CACHE=${cacheDir}" ];
      Restart = "on-failure";
      RestartSec = 10;
      # Loading or downloading a large model must not be cut short.
      TimeoutStartSec = "infinity";
      TimeoutStopSec = 60;
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Merged into the Pi Coding Agent configuration declared in ./agent-tools.nix
  # and written to ~/.pi/agent/models.json.
  #
  # Pi's built-in llama.cpp provider reports every router model as
  # non-reasoning, so the model is declared explicitly here to enable thinking
  # and vision and to pin the real context window.
  programs.pi-coding-agent.models.providers.llamacpp = {
    baseUrl = "${serverUrl}/v1";
    api = "openai-completions";
    # The server runs without --api-key; Pi still wants a value to consider the
    # provider authenticated.
    apiKey = "local";
    compat = {
      # llama.cpp has no prompt store and ignores reasoning_effort.
      supportsStore = false;
      supportsReasoningEffort = false;
      maxTokensField = "max_tokens";
    };
    models = [
      {
        id = qwen.id;
        name = "Qwen3.6 35B A3B (local llama.cpp)";
        reasoning = true;
        input = [
          "text"
          "image"
        ];
        contextWindow = qwen.contextWindow;
        maxTokens = qwen.maxTokens;
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
        compat = {
          # Qwen3.6 toggles thinking through
          # chat_template_kwargs.enable_thinking / .preserve_thinking.
          thinkingFormat = "qwen-chat-template";
        };
      }
    ];
  };
}
