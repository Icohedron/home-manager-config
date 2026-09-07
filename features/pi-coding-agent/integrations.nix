# Declarative pi integrations for the other terminal tools installed here.
#
# Both artifacts below are derived at build time from the exact package version
# nixpkgs provides, so they can never drift from the installed tool:
#   - herdr's pi agent-state extension (normally installed imperatively)
#   - tuicr's agent skill (shipped inside the tuicr source tree)
{ ... }:
{
  flake.modules.homeManager.pi-coding-agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      piConfigDir = config.programs.pi-coding-agent.configDir;

      # Herdr (see ../herdr) only detects pi once its agent-state extension is
      # installed, which `herdr integration install pi` normally does
      # imperatively. Instead, run that same command at build time against a
      # throwaway HOME and capture the generated extension, so Home Manager can
      # link it declaratively. The extension stays in sync with whatever herdr
      # version nixpkgs provides.
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

      # tuicr (see ../tuicr) ships an agent skill in its source tree. nixpkgs
      # builds the binary from that same source, so derive the skill from
      # `pkgs.tuicr.src` rather than vendoring a copy: it always matches the
      # installed tuicr version, exactly like the herdr extension above.
      #
      # Only the Herdr launcher is installed, because herdr is the multiplexer
      # used here and neither tmux, Zellij nor cmux is available. The wrapper
      # shells out to `herdr`, `jq` and `tuicr`, so it is wrapped with those
      # binaries instead of relying on whatever PATH the agent happens to have.
      tuicrPackage = pkgs.tuicr;
      tuicrSkillEnable = herdrCfg.enable && herdrCfg.package != null;
      # Appended to the upstream SKILL.md so the model knows which launcher
      # exists on this machine and where it lives.
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
    in
    {
      home.file =
        lib.optionalAttrs (herdrCfg.enable && herdrCfg.package != null) {
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
    };
}
