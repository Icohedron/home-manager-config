# Command palette: an fzf picker over every action of every installed herdr
# plugin (https://github.com/JanTvrdik/herdr-command-palette).
#
# Pure shell, so the plugin root is just the repo checkout. Upstream has no
# releases yet, hence the pinned commit. `palette.sh` needs fzf and jq on PATH;
# both come from ../../cli-tools.nix and ../../base-packages.nix.
#
# herdr 0.7 ignores keys declared in a plugin manifest; the binding for this
# plugin is in ../default.nix, with the other plugin keys.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  pluginRoot = pkgs.fetchFromGitHub {
    owner = "JanTvrdik";
    repo = "herdr-command-palette";
    rev = "eab940018c2135ac23718efa11e23e9dddcd2a75"; # main; upstream has no releases
    hash = "sha256-A43Dl365S/5w2wrttV1RnQ1g7YRJmsD3tb5EUUZcQQY=";
  };
in
{
  # herdr's plugin registry is mutable state that records a resolved path, so
  # re-link on every switch to follow the store path.
  home.activation.linkHerdrCommandPalette = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${config.programs.herdr.package}/bin/herdr plugin link ${pluginRoot} >/dev/null \
      || warnEcho "herdr: could not link the command-palette plugin"
  '';
}
