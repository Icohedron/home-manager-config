# Git-centric tools plus Git, Jujutsu, and terminal VCS workflow integration.
{
  gitUsername,
  gitEmail,
  ...
}:
{
  programs.lazygit.enable = true;
  programs.gh.enable = true;
  programs.gitui.enable = true;
  programs.delta.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = gitUsername;
        email = gitEmail;
        signingkey = "~/.ssh/id_ed25519.pub";
      };
      core.editor = "hx";
      delta.navigate = true;
      delta.dark = true;
      merge.conflictstyle = "zdiff3";
      commit.gpgsign = true;
      gpg.format = "ssh";
    };
    signing.format = null;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = gitUsername;
        email = gitEmail;
      };
      signing = {
        sign-all = true;
        backend = "ssh";
        key = "~/.ssh/id_ed25519.pub";
      };
      ui.editor = "hx";
    };
  };
}
