# Everyday terminal tools, navigation helpers, and terminal UI configuration.
{ ... }:
{
  programs.bat.enable = true;
  programs.btop.enable = true;
  programs.eza.enable = true;
  programs.fastfetch.enable = true;
  programs.fd.enable = true;
  programs.fzf.enable = true;
  programs.ripgrep.enable = true;
  programs.ripgrep-all.enable = true;

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  # Herdr: terminal workspace/agent multiplexer (https://herdr.dev).
  # Config is rendered to ~/.config/herdr/config.toml by Home Manager.
  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;
      terminal.default_shell = "zsh";
    };
  };

  programs.zellij.enable = true;
  programs.zellij.enableZshIntegration = false;
  programs.zellij.enableBashIntegration = false;
  programs.zellij.settings.default_shell = "zsh";

  xdg.configFile."zellij/config.kdl".text = ''
    show_startup_tips false
    mouse_mode true

    keybinds {
        shared_except "locked" {
            bind "Alt g" {
                Run "lazygit" {
                    floating true
                    x "10%"
                    y "10%"
                    width "80%"
                    height "80%"
                }
            }
        }
    }
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide.enable = true;
}
