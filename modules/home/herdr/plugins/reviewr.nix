# reviewr: a code-review pane for herdr (https://github.com/persiyanov/herdr-reviewr).
#
# `herdr plugin install persiyanov/herdr-reviewr` would download the release
# binary into herdr's mutable plugin state. Instead the plugin root is assembled
# here so the version is pinned by this flake, and `herdr plugin link` registers
# it on activation.
#
# Plugin settings (theme, scopes, keybindings) are not read from herdr's own
# config: they belong in ~/.config/herdr/plugins/config/persiyanov.reviewr/config.toml,
# which is written below (the path is what `herdr plugin config-dir persiyanov.reviewr`
# resolves to).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  version = "0.31.0";

  tomlFormat = pkgs.formats.toml { };

  src = pkgs.fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    rev = "v${version}";
    hash = "sha256-iiTK8j7+mdQ3tWU9Ra96jAGGYwR3D6dZRewG9BO2EWY=";
  };

  # Prebuilt binary for this flake's only system (see flake.nix).
  binary = pkgs.fetchurl {
    url = "https://github.com/persiyanov/herdr-reviewr/releases/download/v${version}/herdr-reviewr-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-l9lx7IFO8Bg8jns7jpg/MW1FGRR+diFdHbfB2ra7vis=";
  };

  pluginRoot = pkgs.runCommand "herdr-reviewr-${version}" { } ''
    mkdir -p $out/bin
    cp ${src}/herdr-plugin.toml $out/
    cp -r ${src}/herdr $out/
    tar -xzf ${binary} -C $out/bin
  '';
in
{
  # herdr's plugin registry is mutable state that records a resolved path, so
  # re-link on every switch to follow the store path.
  home.activation.linkHerdrReviewr = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${config.programs.herdr.package}/bin/herdr plugin link ${pluginRoot} >/dev/null \
      || warnEcho "herdr: could not link the reviewr plugin"
  '';
}
