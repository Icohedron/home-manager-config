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

  # tuicr (installed in ./base-packages.nix, configured in ./cli-tools.nix)
  # ships an agent skill in its source tree. nixpkgs builds the binary from that
  # same source, so derive the skill from `pkgs.tuicr.src` rather than vendoring
  # a copy: it always matches the installed tuicr version, exactly like the
  # herdr extension above.
  #
  # Only the Herdr launcher is installed, because herdr (see ./herdr) is the
  # multiplexer used here and neither tmux, Zellij nor cmux is available. The
  # wrapper shells out to `herdr`, `jq` and `tuicr`, so it is wrapped with those
  # binaries instead of relying on whatever PATH the agent happens to have.
  tuicrPackage = pkgs.tuicr;
  tuicrSkillEnable = herdrCfg.enable && herdrCfg.package != null;
  # Appended to the upstream SKILL.md so the model knows which launcher exists
  # on this machine and where it lives.
  tuicrSkillLocalNotes = pkgs.writeText "tuicr-skill-local-notes.md" ''

    ## Local Environment (Herdr)

    This copy of the skill is installed from version ${tuicrPackage.version} of tuicr.

    - Herdr is the only multiplexer here and every Pi pane runs inside it, so
      `$HERDR_ENV` is `1`. Ignore the cmux, tmux and Zellij rows of the launcher
      table above: those wrappers are not installed.
    - Wrapper path: `~/.pi/agent/skills/tuicr/tuicr-wrapper-herdr.sh`
    - The wrapper already carries `tuicr`, `herdr`, `jq` and `bash` on its own
      PATH, so it works even when they are missing from the agent PATH.
    - Set `TUICR_PANE_DIRECTION=down` for a horizontal split; the default is `right`.
  '';
  tuicrSkill =
    pkgs.runCommand "tuicr-pi-skill-${tuicrPackage.version}"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        skillSrc = "${tuicrPackage.src}/skills/tuicr";
        wrapperPath = lib.makeBinPath (
          [
            pkgs.bash
            pkgs.coreutils
            pkgs.jq
            tuicrPackage
          ]
          ++ lib.optional (herdrCfg.package != null) herdrCfg.package
        );
      }
      ''
        # Fail loudly if a tuicr update drops or renames the skill files rather
        # than silently installing an empty skill.
        for required in SKILL.md tuicr-wrapper-herdr.sh; do
          if [ ! -f "$skillSrc/$required" ]; then
            echo "tuicr ${tuicrPackage.version} no longer ships skills/tuicr/$required" >&2
            exit 1
          fi
        done

        mkdir -p "$out"
        cat "$skillSrc/SKILL.md" ${tuicrSkillLocalNotes} > "$out/SKILL.md"

        install -Dm755 "$skillSrc/tuicr-wrapper-herdr.sh" \
          "$out/libexec/tuicr-wrapper-herdr.sh"
        patchShebangs "$out/libexec"
        makeWrapper "$out/libexec/tuicr-wrapper-herdr.sh" \
          "$out/tuicr-wrapper-herdr.sh" \
          --prefix PATH : "$wrapperPath"
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
        "~/.local/share/tuicr/reviews"
        "${piConfigDir}"
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
        "~/.local/share/tuicr/reviews"
        # workspaces
        "~/hlsl-dev"
      ];
    };
    network = {
      allowNetwork = false;
      allowLocalBinding = true;
      allowAllUnixSockets = true;
      allowedDomains = [ ];
      deniedDomains = [ ];
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
        "sudo *" = "ask";
        "herdr *" = "ask";
        "python *" = "ask";
        "distrobox*" = "ask";
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
  }
  // lib.optionalAttrs tuicrSkillEnable {
    # Linked file-by-file (recursive) so pi's skill discovery walks a real
    # directory instead of a symlink to the store.
    "${piConfigDir}/skills/tuicr" = {
      source = tuicrSkill;
      recursive = true;
    };
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

      # tuicr skill dependencies (its Herdr wrapper is wrapped separately)
      pkgs.tuicr
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
        "npm:pi-subagents"
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
}
