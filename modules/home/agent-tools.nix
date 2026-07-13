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
            id = "openbmb/minicpm5:latest";
            name = "MiniCPM 5 (Local)";
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
      defaultProvider = "ollama";
      defaultModel = "openbmb/minicpm5:latest";
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
