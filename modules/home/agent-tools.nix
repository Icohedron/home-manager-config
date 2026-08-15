# AI/agent tooling, supporting utilities, and the isolated npm setup used by pi.
#
# The local llama.cpp server and the Pi model entry it provides live in
# ./llama-cpp.nix; Home Manager merges that provider into
# programs.pi-coding-agent.models.
{
  config,
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
  piNpmWrapper = pkgs.writeShellScriptBin "pi-npm" ''
    exec ${pkgs.nodejs}/bin/npm \
      --cache ${lib.escapeShellArg piNpmCacheDir} \
      --registry ${lib.escapeShellArg npmRegistry} \
      "$@"
  '';

  # Herdr (see ./herdr) only detects pi once its agent-state extension is
  # installed, which `herdr integration install pi` normally does imperatively.
  # Instead, run that same command at build time against a throwaway HOME and
  # capture the generated extension, so Home Manager can link it declaratively.
  # The extension stays in sync with whatever herdr version nixpkgs provides.
  herdrCfg = config.programs.herdr;
  herdrPiExtension =
    pkgs.runCommand "herdr-pi-agent-state-extension"
      {
        nativeBuildInputs = [ herdrCfg.package ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME/.pi/agent/extensions"
        herdr integration install pi
        cp "$HOME/.pi/agent/extensions/herdr-agent-state.ts" "$out"
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

  piSandboxConfig = (pkgs.formats.json { }).generate "sandbox.json" {
    enabled = true;
    shell.readAccess = "policy";
    filesystem = {
      denyRead = [
        "/Users"
        "/home"
        "/var/home"
      ];
      allowRead = [
        "."
        "~/.gitconfig"
        "~/.config/git/config"
        "~/.cache/mesa_shader_cache"
        "~/.cache/shader_validation_cache-*.bin"
        # workspaces
        "~/hlsl-dev"
      ];
      denyWrite = [
        "**/.env"
        "**/.direnv"
        "**/.envrc"
        "**/.env.*"
        "**/*.pem"
        "**/*.key"
        ".pi/sandbox.json"
        "~/.pi/agent/sandbox.json"
      ];
      allowWrite = [
        "."
        "/dev/null"
        "/dev/shm"
        "/tmp"
        "~/.cache/mesa_shader_cache"
        "~/.cache/shader_validation_cache-*.bin"
        # workspaces
        "~/hlsl-dev"
      ];
    };
    network = {
      allowNetwork = false;
      allowLocalBinding = true;
      allowAllUnixSockets = true;
      allowedDomains = [];
      deniedDomains= [];
    };
  };

  # Note: Let the sandbox configuration handle file permissions
  piPermissionsConfig = (pkgs.formats.json { }).generate "config.json" {
    permission = {
      "*" = "allow";
      path = {
        "*" = "allow";
      };
      bash = {
        "*" = "allow";
        "sudo *" = "deny";
        "herdr *" = "deny";
        "distrobox*" = "deny";
      };
      read = "allow";
      write = "allow";
      edit = "allow";
      external_directory = "allow";
    };
  };
in
{
  home.activation.ensurePiNpmCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg piNpmCacheDir}
  '';

  home.file = {
    "${piConfigDir}/extensions/pi-tool-display/config.json".source = piToolDisplayConfig;
    "${piConfigDir}/extensions/pi-permission-system/config.json".source = piPermissionsConfig;
    "${piConfigDir}/sandbox.json".source = piSandboxConfig;
  }
  // lib.optionalAttrs (herdrCfg.enable && herdrCfg.package != null) {
    "${piConfigDir}/extensions/herdr-agent-state.ts".source = herdrPiExtension;
  };

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;
    configDir = piConfigDir;
    extraPackages = [
      piNpmWrapper

      # General nodejs dependencies
      pkgs.nodejs
      pkgs.bun

      # pi-drawio dependencies
      pkgs.drawio

      # pi-codegraph dependencies
      pkgs.codegraph

      # pi-sandbox dependencies
      pkgs.ripgrep
      pkgs.bubblewrap
      pkgs.socat

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
        # Isolation and permissions
        "npm:pi-landstrip"
        "npm:@gotgenes/pi-permission-system"
        # Others
        "npm:pi-mcp-adapter"
        "npm:@tmustier/pi-files-widget"
        "npm:@vndv/pi-codegraph"
        "npm:pi-simplify"
        "npm:pi-schedule-prompt"
        "npm:pi-observational-memory"
        "npm:pi-subagents"
        "npm:pi-tool-display"
        "npm:pi-zentui"
        "npm:pi-drawio"
        "npm:pi-readseek"
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
}
