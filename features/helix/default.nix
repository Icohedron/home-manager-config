# Helix - the default editor, plus the language definitions it needs.
#
# The HLSL tree-sitter queries live next to this file in ./hlsl-queries and are
# linked into Helix's runtime directory.
{ config, ... }:
{
  flake.modules.homeManager.helix = {
    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "catppuccin_mocha";

        editor = {
          auto-save = true;
          bufferline = "always";
          cursorcolumn = true;
          cursorline = true;
          mouse = true;
          rulers = [ 80 ];
          text-width = 80;
          true-color = true;

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          file-picker.hidden = false;

          soft-wrap = {
            enable = true;
            wrap-at-text-width = false;
            wrap-indicator = "↩ ";
          };

          statusline = {
            center = [ "file-name" ];
            left = [
              "mode"
              "spinner"
            ];
            right = [
              "diagnostics"
              "selections"
              "position"
              "file-encoding"
              "file-line-ending"
              "file-type"
            ];
            separator = "|";

            mode = {
              insert = "INSERT";
              normal = "NORMAL";
              select = "SELECT";
            };
          };

          whitespace.characters = {
            nbsp = "⍽";
            newline = "⏎";
            nnbsp = "␣";
            space = "·";
            tab = "→";
            tabpad = "·";
          };

          whitespace.render = {
            nbsp = "none";
            newline = "all";
            nnbsp = "none";
            space = "none";
            tab = "all";
          };

          indent-guides.render = true;

          inline-diagnostics.cursor-line = "hint";
        };
      };

      languages.language = [
        {
          name = "nix";
          scope = "source.nix";
          injection-regex = "nix";
          file-types = [ "nix" ];
          shebangs = [ ];
          comment-token = "#";
          language-servers = [
            "nil"
            "nixd"
          ];
          indent = {
            tab-width = 2;
            unit = "  ";
          };
          formatter.command = "nixfmt";
        }
        {
          name = "hlsl";
          scope = "source.hlsl";
          injection-regex = "hlsl";
          file-types = [
            "hlsl"
            "fx"
            "cginc"
            "compute"
          ];
          comment-token = "//";
          grammar = "c";
          language-servers = [ ];
          indent = {
            tab-width = 4;
            unit = "    ";
          };
        }
      ];
    };

    # HLSL has no upstream grammar in Helix; reuse the C queries.
    xdg.configFile."helix/runtime/queries/hlsl" = {
      source = ./hlsl-queries;
      recursive = true;
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.helix ];
}
