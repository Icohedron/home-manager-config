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

      # Herdr (see ../herdr.nix) only detects pi once its agent-state extension
      # is installed, which `herdr integration install pi` normally does
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

      # Build from the same tuicr source as the installed binary, with just
      # the Herdr launcher and a wrapper carrying its runtime dependencies.
      tuicrSkillEnable = herdrCfg.enable && herdrCfg.package != null;
      tuicrSkill = import ../tuicr/_skill.nix {
        inherit pkgs lib;
        herdrPackage = herdrCfg.package;
        agentName = "pi";
        skillPath = "~/.pi/agent/skills/tuicr";
      };
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
