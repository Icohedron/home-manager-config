# pi coding agent - the agent itself, its packages and its settings.
#
# The rest of this directory extends the same Home Manager module:
#   ./sandbox.nix      - pi-landstrip filesystem/network policy
#   ./integrations.nix - herdr extension and tuicr skill wiring
#   ./models.nix       - local llama.cpp provider and model declaration
{ config, ... }:
let
  inherit (config.user) homeDirectory npmRegistry;
in
{
  flake.modules.homeManager.pi-coding-agent =
    { lib, pkgs, ... }:
    let
      # Keep pi's npm state isolated from the user's global ~/.npm directory.
      # npmRegistry is provided per-user from user.nix (see ../registries.nix for
      # the global npm/PyPI/NuGet registry configuration).
      piConfigDir = "${homeDirectory}/.pi/agent";
      piNpmCacheDir = "${homeDirectory}/.pi/.npm";
      piNpmWrapper = pkgs.writeShellScriptBin "pi-npm" ''
        exec ${pkgs.nodejs}/bin/npm \
          --cache ${lib.escapeShellArg piNpmCacheDir} \
          --registry ${lib.escapeShellArg npmRegistry} \
          "$@"
      '';

      piToolDisplayConfig = (pkgs.formats.json { }).generate "config.json" {
        registerToolOverrides = {
          "write" = false;
          "read" = false;
          "grep" = false;
          "edit" = false;
          "bash" = false;
          "find" = true;
          "ls" = true;
        };
      };
    in
    {
      home.activation.ensurePiNpmCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${lib.escapeShellArg piNpmCacheDir}
      '';

      home.file."${piConfigDir}/extensions/pi-tool-display/config.json".source = piToolDisplayConfig;

      programs.pi-coding-agent = {
        enable = true;
        package = pkgs.pi-coding-agent;
        configDir = piConfigDir;
        extraPackages = [
          piNpmWrapper

          # General nodejs dependencies
          pkgs.nodejs
          pkgs.bun
        ];
        settings = {
          npmCommand = [ "${piNpmWrapper}/bin/pi-npm" ];
          defaultProvider = "github-copilot";
          defaultModel = "claude-opus-5";
          defaultThinkingLevel = "high";
          packages = [
            # Sandbox
            "npm:pi-landstrip"
            # Others
            "npm:pi-mcp-adapter"
            "npm:pi-simplify"
            "npm:pi-tool-display"
            "npm:pi-zentui"
            "npm:pi-drawio"
            "npm:pi-readseek"
            "npm:pi-smart-compact"
          ];

          readseek = {
            overrideTools = [
              "write"
              "read"
              "grep"
              "edit"
            ];
            imageMode = "auto";
            syntaxValidation = "warn";
            timeoutMs = 120000;
            grep = {
              maxLines = 2000;
              maxBytes = 51200;
            };
            display = {
              grep = "compact";
              edit = "expanded";
              write = "expanded";
            };
          };
        };
      };
    };

  flake.modules.homeManager.workstation.imports = [
    config.flake.modules.homeManager.pi-coding-agent
  ];
}
