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

  # Herdr and its plugins live in ./herdr.

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
      { id = "note", definition = "note for reviewers", color = "gray" },
      { id = "question", definition = "ask for clarification", color = "magenta" },
      { id = "issue", definition = "problems to fix", color = "red" },
      { id = "suggestion", definition = "possible improvements", color = "orange" },
      { id = "nit", label = "nitpick", definition = "small optional tweaks", color = "yellow" },
      { id = "praise", definition = "positive feedback", color = "green" },
    ]
    '';
}
