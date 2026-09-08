# devcontainer - reference CLI for devcontainer.json environments.
#
# The CLI assumes Docker: it shells out to `docker`, and this machine runs
# podman instead (see `hardware.containerEngine` in system/hardware.nix, and
# features/podman.nix for the engine itself).
#
# Podman works, but only when the CLI is *told* about it: given
# `--docker-path podman` it adapts the commands it builds (adding
# `--security-opt label=disable`, for example), which it does not do when it
# believes it is talking to Docker. That flag is per-subcommand, so it has to
# be injected after the subcommand rather than set once.
{ config, ... }:
let
  engine = config.hardware.containerEngine;
in
{
  flake.modules.homeManager.devcontainer =
    { lib, pkgs, ... }:
    let
      devcontainer = pkgs.devcontainer;

      # Ask the installed CLI which subcommands accept --docker-path instead of
      # hardcoding a list that a version bump could silently invalidate.
      dockerPathSubcommands =
        pkgs.runCommand "devcontainer-docker-path-subcommands-${devcontainer.version}"
          {
            nativeBuildInputs = [ devcontainer ];
          }
          ''
            touch "$out"
            for cmd in up set-up build run-user-commands read-configuration exec outdated features templates; do
              if devcontainer "$cmd" --help 2>/dev/null | grep -q -- '--docker-path'; then
                echo "$cmd" >> "$out"
              fi
            done

            if [ ! -s "$out" ]; then
              echo "devcontainer ${devcontainer.version} no longer accepts --docker-path" >&2
              exit 1
            fi
          '';

      podmanDevcontainer = pkgs.writeShellApplication {
        name = "devcontainer";
        text = ''
          subcommand="''${1-}"

          inject=0
          if [ -n "$subcommand" ] && grep -qxF -- "$subcommand" ${dockerPathSubcommands}; then
            inject=1
          fi

          # Never override an explicit choice.
          for arg in "$@"; do
            case "$arg" in
            --docker-path | --docker-path=*) inject=0 ;;
            esac
          done

          # Compose-based devcontainers are driven through docker-compose, which
          # speaks the Docker API rather than running the CLI; podman serves that
          # same API on its own socket.
          if [ -z "''${DOCKER_HOST:-}" ]; then
            socket="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
            if [ -S "$socket" ]; then
              export DOCKER_HOST="unix://$socket"
            fi
          fi

          if [ "$inject" = 1 ]; then
            shift
            set -- "$subcommand" --docker-path ${lib.getExe pkgs.podman} "$@"
          fi

          exec ${lib.getExe devcontainer} "$@"
        '';
      };
    in
    {
      home.packages = [
        (if engine == "podman" then podmanDevcontainer else devcontainer)
      ];
    };

  flake.modules.homeManager.workstation.imports = [
    config.flake.modules.homeManager.devcontainer
  ];
}
