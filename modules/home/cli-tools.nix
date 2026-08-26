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

  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;
      terminal.default_shell = "zsh";
      session.resume_agents_on_restore = true;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide.enable = true;

  xdg.configFile."tuicr/config.toml".text = ''
    theme = "catppuccin-mocha"
    diff_view = "side-by-side"
    ignore_whitespace = false
    mouse = true
    leader = ";"
    comment_vim = true
    relative_line_numbers = false

    comment_types = [
      { id = "note", definition = "note for reviewers", color = "#b2b2b2" },
      { id = "question", definition = "ask for clarification", color = "#a7ecf3" },
      { id = "issue", definition = "problems to fix", color = "#f61a1a" },
      { id = "suggestion", definition = "possible improvements", color = "#f6972a" },
      { id = "nit", label = "nitpick", definition = "small optional tweaks", color = "#f7f12a" },
      { id = "praise", definition = "positive feedback", color = "#25f230" },
    ]
    '';
}
