# pi-landstrip sandbox policy: what the agent may read, write and reach.
{ ... }:
{
  flake.modules.homeManager.pi-coding-agent =
    { config, pkgs, ... }:
    let
      piConfigDir = config.programs.pi-coding-agent.configDir;

      piLandStripConfig = (pkgs.formats.json { }).generate "pi-landlock.json" {
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
          allowAllUnixSockets = false;
          allowedDomains = [ ];
          deniedDomains = [ ];
        };
      };
    in
    {
      home.file."${piConfigDir}/sandbox.json".source = piLandStripConfig;
    };
}
