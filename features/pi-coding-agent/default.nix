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
    in
    {
      home.activation.ensurePiNpmCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${lib.escapeShellArg piNpmCacheDir}
      '';

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
            "git:github.com/Icohedron/pi-devcontainer"
            "npm:pi-simplify"
            "npm:pi-zentui"
            "npm:pi-drawio"
            "npm:pi-smart-compact"
          ];

          devcontainer = {
            enabled = true;
            runtime = "podman";
            runtimeArgs = [ ];
            execArgs = [ ];
            devcontainerPath = "devcontainer";
            upArgs = [ ];
            hostCommands = [ "tuicr" ];
            tools = [
              "read"
              "write"
              "edit"
              "bash"
              "grep"
              "find"
              "ls"
            ];
            userBash = "container";
            requireContainer = false;
          };
        };
      };
    };

  flake.modules.homeManager.workstation.imports = [
    config.flake.modules.homeManager.pi-coding-agent
  ];
}
