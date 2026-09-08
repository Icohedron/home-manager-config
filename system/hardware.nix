# Hardware profile of this machine.
#
# Facts that Nix cannot work out on its own (display server, GPU compute stack)
# are decided here; features consume these options instead of guessing. The CPU
# architecture is deliberately absent: it comes from the platform the
# configuration is built for (see ./nixpkgs.nix and ./configurations.nix).
#
# Defaults come from ../user.nix, but they can be pinned directly in this file
# when a machine needs something different.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.hardware = {
    wayland = mkOption {
      type = types.bool;
      default = config.user.useWayland;
      defaultText = "config.user.useWayland";
      description = "Whether the graphical session speaks Wayland instead of X11.";
    };

    containerEngine = mkOption {
      type = types.enum [
        "docker"
        "podman"
      ];
      default = "podman";
      description = ''
        Container engine this machine provides.

        With "podman", features/podman.nix installs it, and tools that assume
        Docker are adapted to it: features/devcontainer.nix wraps the
        devcontainer CLI so it drives podman instead of looking for a Docker
        daemon. Set it to "docker" on a machine that runs dockerd, and podman
        is left out while the CLI is installed unwrapped.
      '';
    };

    gpuBackend = mkOption {
      type = types.enum [
        "cuda"
        "vulkan"
        "cpu"
      ];
      default = config.user.llamaCppGPUBackend;
      defaultText = "config.user.llamaCppGPUBackend";
      description = ''
        GPU compute stack usable on this machine:

        - "cuda"   NVIDIA GPU with the proprietary driver
        - "vulkan" any GPU with a native Vulkan driver
        - "cpu"    no GPU offload

        Consumed by features/llama-cpp.
      '';
    };
  };

  # Packages that only make sense for this machine's hardware.
  config.flake.modules.homeManager.hardware =
    { pkgs, ... }:
    {
      # Clipboard bridge for the display server in use. macOS ships pbcopy and
      # pbpaste, so this is a Linux-only concern.
      home.packages = lib.optional pkgs.stdenv.hostPlatform.isLinux (
        if config.hardware.wayland then pkgs.wl-clipboard else pkgs.xsel
      );
    };
}
