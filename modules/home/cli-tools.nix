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
    comment_vim = false
    relative_line_numbers = false

    [[comment_types]]
    id = "issue"
    color = "red"
    definition = "must fix before merge"
  '';
}
