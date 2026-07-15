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
  # npmRegistry is provided per-user from users.nix.
  piNpmCacheDir = "${homeDirectory}/.pi/.npm";
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

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;
    configDir = "${homeDirectory}/.pi/agent";
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
      defaultModel = "claude-opus-4.8";
      defaultThinkingLevel = "high";
      packages = [
        "npm:pi-mcp-adapter"
        "npm:@tmustier/pi-files-widget"
        "npm:@vndv/pi-codegraph"
        "npm:pi-readseek"
        "npm:pi-web-access"
        "npm:pi-simplify"
        "npm:pi-schedule-prompt"
        "npm:pi-observational-memory"
        "git:github.com/HazAT/pi-interactive-subagents"
      ];
      readseek = {
        replacedTools = [ "read" "edit" "write" "grep" ];
        imageMode = "auto";
        syntaxValidation = "warn";
      };
    };
  };
}
