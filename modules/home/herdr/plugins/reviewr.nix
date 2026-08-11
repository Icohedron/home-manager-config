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
  version = "0.30.1";

  tomlFormat = pkgs.formats.toml { };

  src = pkgs.fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    rev = "v${version}";
    hash = "sha256-U+h5iMtkSslElRpcohGzVK1xbfsepJV9vNPO05IRwag=";
  };

  # Prebuilt binary for this flake's only system (see flake.nix).
  binary = pkgs.fetchurl {
    url = "https://github.com/persiyanov/herdr-reviewr/releases/download/v${version}/herdr-reviewr-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-TAIzZeDIymem8uSmJWrxxJqRanqFPpRSbt93qXrn8hM=";
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

  # Focus on toggle is not a setting of its own: reviewr derives it from the placement.
  # `herdr/pane.sh` passes `--no-focus` for a `split` open and `--focus` for every other
  # placement, on purpose (specs/herdr-host.md: "A manual open keeps focus on the agent
  # for `split`, and gives focus to reviewr otherwise"). With no config file the default
  # placement is `split`, which is why prefix+d left the keyboard on the agent.
  #
  # `zoomed` still attaches to the focused pane, so reviewr stays a real pane in the
  # layout, but it opens focused and filling the tab; prefix+z unzooms to the familiar
  # side-by-side view without losing focus. `overlay` and `tab` also take focus.
  #
  # Trade-off: the plugin's worktree.created auto-open only fires for `split` and `tab`
  # (herdr/pane.sh), so it is inert under `zoomed`. Switch to `tab` to keep both.
  #
  # reviewr rejects the whole file on an unknown key or invalid value, and re-reads it on
  # every toggle and refresh, so no herdr restart is needed after a switch.
  xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source =
    tomlFormat.generate "herdr-reviewr-config.toml" {
      toggle_placement = "zoomed";
    };
}
