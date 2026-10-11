# Build the Herdr-only tuicr skill for either agent from the installed tuicr source.
{
  pkgs,
  lib,
  herdrPackage,
  agentName,
  skillPath,
}:
let
  tuicrPackage = pkgs.tuicr;
  localNotes = pkgs.writeText "tuicr-${lib.toLower agentName}-skill-notes.md" ''

    ## Local Environment (Herdr)

    This copy of the skill is installed from version ${tuicrPackage.version} of tuicr.

    - Herdr is the configured multiplexer. Ignore the cmux, tmux and Zellij
      launchers: those wrappers are not installed here.
    - Wrapper path: `${skillPath}/tuicr-wrapper-herdr.sh`
    - The wrapper carries `tuicr`, `herdr`, `jq` and `bash` on its own PATH.
    - Set `TUICR_PANE_DIRECTION=down` for a horizontal split; the default is `right`.
  '';
in
pkgs.runCommand "tuicr-${lib.toLower agentName}-skill-${tuicrPackage.version}"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    skillSrc = "${tuicrPackage.src}/skills/tuicr";
    wrapperPath = lib.makeBinPath [
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
      tuicrPackage
      herdrPackage
    ];
  }
  ''
    for required in SKILL.md tuicr-wrapper-herdr.sh; do
      if [ ! -f "$skillSrc/$required" ]; then
        echo "tuicr ${tuicrPackage.version} no longer ships skills/tuicr/$required" >&2
        exit 1
      fi
    done

    mkdir -p "$out"
    cat "$skillSrc/SKILL.md" ${localNotes} > "$out/SKILL.md"

    install -Dm755 "$skillSrc/tuicr-wrapper-herdr.sh" \
      "$out/libexec/tuicr-wrapper-herdr.sh"
    patchShebangs "$out/libexec"
    makeWrapper "$out/libexec/tuicr-wrapper-herdr.sh" \
      "$out/tuicr-wrapper-herdr.sh" \
      --prefix PATH : "$wrapperPath"
  ''
