# Zed - GUI editor. Language server binaries are contributed by the toolchain
# features (see ./clangd.nix).
{ config, ... }:
{
  flake.modules.homeManager.zed-editor = {
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
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.zed-editor ];
}
