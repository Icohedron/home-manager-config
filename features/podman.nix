# podman - daemonless container engine, run rootless.
#
# Installed only when this machine's `hardware.containerEngine` is "podman";
# on a Docker machine the feature stays in the repository but out of the
# profile. features/devcontainer.nix drives the same engine.
#
# Home Manager's module does everything else: it installs podman and writes the
# per-user copies of the container configuration a distribution keeps in
# /etc/containers - without policy.json podman refuses to pull any image at
# all. Its defaults are right here, so nothing is overridden.
#
# `ignore_chown_errors` deliberately stays off. It lets images unpack while the
# user owns a single id (an empty /etc/subuid, how a distrobox container
# starts), but those layers cannot be id-mapped afterwards: `--userns=keep-id`
# breaks, and with it every devcontainer, and podman can neither read nor
# delete what it wrote. A failed pull is the better outcome - it names
# /etc/subuid, and the README explains how to grant a range there.
{ config, lib, ... }:
let
  engine = config.hardware.containerEngine;
  podmanModule = config.flake.modules.homeManager.podman;
in
{
  flake.modules.homeManager.podman = {
    services.podman.enable = true;
  };

  flake.modules.homeManager.workstation.imports = lib.optional (engine == "podman") podmanModule;
}
