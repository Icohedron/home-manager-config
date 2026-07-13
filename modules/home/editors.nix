# Editor and IDE configuration, including shared language tooling and custom runtime files.
{
  pkgs,
  ...
}:
let
  # Use clangd from clang-tools so clangd can find the standard C/C++ headers
  # expected by local toolchains.
  clangdPackage = pkgs.llvmPackages_latest.clang-tools.override { enableLibcxx = false; };
  clangdPath = "${clangdPackage}/bin/clangd";
in
{
  home.packages = [
    pkgs.nil
    pkgs.nixd
    pkgs.nixfmt
  ];

  programs.zed-editor = {
    enable = true;
    userSettings = {
      edit_predictions.provider = "copilot";
      agent_servers.opencode.type = "registry";
      agent = {
        default_model = {
          provider = "copilot_chat";
          model = "claude-opus-4.8";
          enable_thinking = true;
          effort = "high";
        };
        favorite_models = [ ];
        model_parameters = [ ];
      };
      helix_mode = true;
      which_key = {
        enabled = true;
        delay_ms = 100;
      };
      base_keymap = "VSCode";
      theme = "Aura Dark";
      icon_theme = "Warm Charmed Icons";
      theme_overrides = {
        "Aura Dark" = {
          "border" = "#15141C";
          "border.variant" = "#15141C";
          "panel.background" = "#15141C";
          "tab_bar.background" = "#15141C";
          "terminal.background" = "#15141C";
          "tab.inactive_background" = "#15141C";
          "title_bar.inactive_background" = "#110f18";
          "panel.focused_border" = "#4E466E";
        };
      };
      title_bar = {
        show_user_menu = false;
        show_user_picture = false;
        show_sign_in = false;
      };
      tab_bar.show = true;
      current_line_highlight = "none";
      lsp = {
        "clangd" = {
          binary.path = clangdPath;
        };
      };
    };
    extensions = [
      "aura-theme"
      "charmed-icons"
      "nix"
    ];
    userKeymaps = [
      {
        context = "(VimControl && !menu)";
        bindings = {
          "space" = null;
          "space space c" = "collab_panel::Toggle";
          "space G" = "debug_panel::Toggle";
          "space e" = "project_panel::Toggle";
          "space space g" = "git_panel::Toggle";
          "space space o" = "outline_panel::Toggle";
          "] g" = "editor::GoToHunk";
          "[ g" = "editor::GoToPreviousHunk";
          "] G" = "editor::GoToPreviousDiagnostic";
          "[ G" = "editor::GoToHunk";
          "] d" = "editor::GoToDiagnostic";
          "[ d" = "editor::GoToPreviousDiagnostic";
          "] D" = "editor::GoToPreviousDiagnostic";
          "[ D" = "editor::GoToDiagnostic";
          "=" = "editor::FormatSelections";
        };
      }
      {
        context = "(vim_mode == helix_normal || vim_mode == helix_select) && !menu";
        bindings = {
          "space b" = "tab_switcher::Toggle";
        };
      }
    ];
  };

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

    languages = {
      language-server.clangd = {
        command = clangdPath;
      };

      language = [
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
  };

  xdg.configFile."helix/runtime/queries/hlsl/highlights.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/injections.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/locals.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/textobjects.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/indents.scm".text = "; inherits: c";
}
