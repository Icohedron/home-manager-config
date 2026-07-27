# AI/agent tooling, supporting utilities, and the isolated npm setup used by pi.
{
  lib,
  pkgs,
  homeDirectory,
  npmRegistry,
  ...
}:
let
  # Keep pi's npm state isolated from the user's global ~/.npm directory.
  # npmRegistry is provided per-user from user.nix (see registries.nix for the
  # global npm/PyPI/NuGet registry configuration).
  piConfigDir = "${homeDirectory}/.pi/agent";
  piNpmCacheDir = "${homeDirectory}/.pi/.npm";
  # Custom github-copilot entries must include Copilot's static IDE headers or
  # IDE-auth requests fail, so keep an explicit claude-opus-5 alias here.
  piModelsConfig = {
    providers = {
      github-copilot = {
        models = [
          {
            id = "claude-opus-5";
            name = "Claude Opus 5";
            api = "anthropic-messages";
            baseUrl = "https://api.individual.githubcopilot.com";
            headers = {
              User-Agent = "GitHubCopilotChat/0.35.0";
              Editor-Version = "vscode/1.107.0";
              Editor-Plugin-Version = "copilot-chat/0.35.0";
              Copilot-Integration-Id = "vscode-chat";
            };
            reasoning = true;
            thinkingLevelMap = {
              xhigh = "xhigh";
              max = "max";
            };
            input = [ "text" "image" ];
            contextWindow = 1000000;
            maxTokens = 128000;
            cost = {
              input = 5;
              output = 25;
              cacheRead = 0.5;
              cacheWrite = 6.25;
            };
            compat = {
              forceAdaptiveThinking = true;
            };
          }
        ];
      };
    };
  };
  piNpmWrapper = pkgs.writeShellScriptBin "pi-npm" ''
    exec ${pkgs.nodejs}/bin/npm \
      --cache ${lib.escapeShellArg piNpmCacheDir} \
      --registry ${lib.escapeShellArg npmRegistry} \
      "$@"
  '';
in
{
  home.packages = [
    piNpmWrapper
    pkgs.nono
    pkgs.codegraph
  ];

  home.activation.ensurePiNpmCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg piNpmCacheDir}
  '';

  home.file.".pi/agent/models.json".text = builtins.toJSON piModelsConfig;

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;
    configDir = piConfigDir;
    extraPackages = [
      # General nodejs dependencies
      pkgs.nodejs
      pkgs.bun

      # pi-files-widget dependencies
      pkgs.glow
      pkgs.jq
      pkgs.delta
    ];
    settings = {
      npmCommand = [ "${piNpmWrapper}/bin/pi-npm" ];
      defaultProvider = "github-copilot";
      defaultModel = "claude-opus-5";
      defaultThinkingLevel = "high";
      packages = [
        "npm:pi-mcp-adapter"
        "npm:@tmustier/pi-files-widget"
        "npm:@vndv/pi-codegraph"
        "npm:pi-web-access"
        "npm:pi-simplify"
        "npm:pi-schedule-prompt"
        "npm:pi-observational-memory"
        "npm:pi-subagents"
        "npm:pi-tool-display"
        "npm:pi-zentui"
      ];
      readseek = {
        replacedTools = [ "read" "edit" "write" "grep" ];
        imageMode = "auto";
        syntaxValidation = "warn";
      };
    };
  };
}
