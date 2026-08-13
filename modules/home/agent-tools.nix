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

  # Sandbox profile selected with `nono run -p pi ...`.
  nonoPiProfile = (pkgs.formats.json { }).generate "nono-profile-pi.json" {
    extends = "nolabs-ai/pi";
    meta.name = "pi";
    groups = {
      include = [ ];
      exclude = [ ];
    };
    commands = {
      allow = [ ];
      deny = [ "herdr" ];
    };
    # command_policies.commands.herdr.from.session = "deny"; # Causes nono to stall and deny access to all binaries in ~/.nix-profile/bin
    workdir.access = "readwrite";
    filesystem = {
      allow = [
        "/tmp"
        "/dev/shm"
      ];
      read = [ ];
      write = [ ];
      allow_file = [ ];
      read_file = [ ];
      write_file = [ ];
      deny = [ ];
      bypass_protection = [ ];
      suppress_save_prompt = [ ];
    };
    network = {
      block = false;
      allow_domain = [ ];
      credentials = [ ];
      open_port = [ ];
      listen_port = [ ];
      custom_credentials = { };
    };
    env_credentials = { };
    hooks = { };
    rollback = {
      exclude_patterns = [ ];
      exclude_globs = [ ];
    };
    allow_gpu = true;
  };
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

  home.file = lib.mkIf (herdrCfg.enable && herdrCfg.package != null) {
    "${piConfigDir}/extensions/herdr-agent-state.ts".source = herdrPiExtension;
  };

  xdg.configFile."nono/profiles/pi.json".source = nonoPiProfile;

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
        "npm:pi-drawio"
      ];
    };
  };
}
