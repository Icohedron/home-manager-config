# omp - Oh My Pi coding agent
{ config, inputs, ... }:
{
  flake.modules.homeManager.omp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      herdrCfg = config.programs.herdr;

      tuicrSkill = import ./tuicr/_skill.nix {
        inherit pkgs lib;
        herdrPackage = herdrCfg.package;
        agentName = "omp";
        skillPath = "~/.omp/agent/skills/tuicr";
      };

      # OMP discovers only immediate children of skills/. Flatten the active
      # upstream categories, preserving each skill's adjacent assets.
      mattSkills = builtins.listToAttrs (
        lib.concatMap
          (
            category:
            lib.mapAttrsToList
              (name: _: {
                name = ".omp/agent/skills/${name}";
                value = {
                  source = "${inputs.mattpocock-skills}/skills/${category}/${name}";
                  recursive = true;
                };
              })
              (
                lib.filterAttrs (
                  name: kind:
                  kind == "directory"
                  && builtins.pathExists "${inputs.mattpocock-skills}/skills/${category}/${name}/SKILL.md"
                ) (builtins.readDir "${inputs.mattpocock-skills}/skills/${category}")
              )
          )
          [
            "engineering"
            "productivity"
          ]
      );
    in
    {
      home.packages = [ pkgs.omp ];

      # Register the complete pinned package without replacing other plugins.
      home.activation.installOmpIHaveAdhd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe pkgs.omp} plugin link ${inputs.i-have-adhd}
      '';

      home.file =
        mattSkills
        // {
          ".omp/agent/skills/i-have-adhd" = {
            source = "${inputs.i-have-adhd}/skills/i-have-adhd";
            recursive = true;
          };
        }
        // lib.optionalAttrs (herdrCfg.enable && herdrCfg.package != null) {
          # Use the extension bundled with the installed Herdr version. Its
          # source retains a .ts basename after Home Manager links it.
          ".omp/agent/extensions/herdr-omp-agent-state.ts".source =
            "${herdrCfg.package.src}/src/integration/assets/omp/herdr-agent-state.ts";
          # Recursive links leave a real skill directory for OMP's scanner.
          ".omp/agent/skills/tuicr" = {
            source = tuicrSkill;
            recursive = true;
          };
          ".omp/agent/skills/herdr" = {
            source = "${herdrCfg.package.src}/skills/herdr";
            recursive = true;
          };
        };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.omp ];
}
