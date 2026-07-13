# AI/agent tooling, supporting utilities, and the isolated npm setup used by pi.
{
  lib,
  pkgs,
  inputs,
  homeDirectory,
  npmRegistry,
  ...
}:
let
  # Packages from the numtide llm-agents flake are built against its own pinned
  # nixpkgs, which helps the numtide binary cache hit reliably.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Keep pi's npm state isolated from the user's global ~/.npm directory.
  # npmRegistry is provided per-user from users.nix.
  piNpmCacheDir = "${homeDirectory}/.pi/.npm";
  piNpmWrapper = pkgs.writeShellScriptBin "pi-npm" ''
    exec ${pkgs.nodejs}/bin/npm \
      --cache ${lib.escapeShellArg piNpmCacheDir} \
      --registry ${lib.escapeShellArg npmRegistry} \
      "$@"
  '';
  # Context window pi advertises for the local model. This MUST match the
  # context Ollama actually serves (OLLAMA_CONTEXT_LENGTH below); otherwise pi
  # thinks it has more room than Ollama provides and Ollama silently truncates
  # the prompt (dropping tool definitions / system prompt, which breaks tool
  # calling). Raising it costs VRAM, so tune to what the GPU can hold.
  ollamaContextLength = 131072; # 128K (128 * 1024)
  piModels = builtins.toJSON {
    providers = {
      ollama = {
        baseUrl = "http://127.0.0.1:11434/v1";
        api = "openai-completions";
        apiKey = "ollama";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
        };
        models = [
          {
            id = "gemma4:12b";
            name = "Gemma 4 12B (Local)";
            input = [ "text" "image" ];
            contextWindow = ollamaContextLength;
            maxTokens = 16384;
            # gemma4 reports the `thinking` capability. Expose it in pi and let
            # pi send a reasoning effort; Ollama's OpenAI endpoint maps
            # reasoning_effort -> think level. Override the provider-level
            # supportsReasoningEffort = false for this model.
            reasoning = true;
            compat = {
              supportsReasoningEffort = true;
              thinkingFormat = "reasoning_effort";
            };
            # Map pi's thinking levels to the low/medium/high values Ollama
            # understands. null = level hidden/unsupported.
            thinkingLevelMap = {
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = null;
              max = null;
            };
          }
        ];
      };
    };
  };
in
{
  home.packages = [
    piNpmWrapper
    llmAgents.nono
    llmAgents.hermes-agent
    llmAgents.codegraph
    pkgs.smartcat
  ];

  home.activation.ensurePiNpmCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg piNpmCacheDir}
  '';

  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    # Ollama defaults to a small context (~4096) regardless of what the model
    # supports, and pi's OpenAI-compatible requests do not send num_ctx. Set it
    # server-side so long prompts (system prompt + tool schemas) are not
    # truncated. Keep this equal to the model's contextWindow above.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = toString ollamaContextLength;
      # Reduce KV-cache memory so a 128K context can fit in VRAM.
      # q8_0 roughly halves KV-cache size with minimal quality loss and
      # requires flash attention to be enabled. Verify it actually engages on
      # Vulkan via `journalctl --user -u ollama -f` when a model loads.
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  home.file.".pi/agent/models.json".text = piModels;

  programs.pi-coding-agent = {
    enable = true;
    package = llmAgents.pi;
    configDir = "${homeDirectory}/.pi/agent";
    extraPackages = [
      pkgs.nodejs
      pkgs.bun
    ];
    settings = {
      npmCommand = [ "${piNpmWrapper}/bin/pi-npm" ];
      defaultProvider = "github-copilot";
      defaultModel = "claude-opus-4.8";
      defaultThinkingLevel = "high";
      packages = [
        "npm:pi-mcp-adapter"
        "npm:pi-hermes-memory"
        "npm:@tmustier/pi-files-widget"
        "npm:@vndv/pi-codegraph"
        "npm:pi-readseek"
        "npm:pi-web-access"
        "npm:pi-subagents"
        "npm:pi-simplify"
      ];
    };
  };
}
