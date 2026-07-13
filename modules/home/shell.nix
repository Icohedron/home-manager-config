# Interactive shell behavior, prompt setup, shell aliases, and shell-specific integrations.
{
  lib,
  pkgs,
  ...
}:
{
  programs.tirith.enable = true;
  programs.tirith.enableBashIntegration = false; # known bugs with bash
  programs.tirith.enableZshIntegration = true;

  home.shell.enableShellIntegration = true;
  home.shell.enableNushellIntegration = true;
  home.shell.enableZshIntegration = true;
  home.shellAliases = {
    grep = "rg";
    cd = "z";
    cdi = "zi";
  };

  programs.zsh = {
    enable = true;
    initContent = lib.mkMerge [
      ''
        # Fix common navigation/editing keys that are unbound by default,
        # which otherwise insert stray characters (e.g. Delete inserts "~").
        # Bind the terminfo capability plus the common literal escape
        # sequences, since terminals disagree on the exact bytes.

        # Delete (forward delete)
        bindkey "''${terminfo[kdch1]}" delete-char 2>/dev/null
        bindkey "^[[3~" delete-char
        bindkey "^[[3;5~" kill-word # Ctrl+Delete: kill the next word

        # Ctrl+Backspace: kill the previous word
        # (terminals send ^H (0x08) or the CSI-u sequence for Ctrl+Backspace)
        bindkey "^H" backward-kill-word
        bindkey "^[[127;5u" backward-kill-word

        # Home
        bindkey "''${terminfo[khome]}" beginning-of-line 2>/dev/null
        bindkey "^[[H" beginning-of-line
        bindkey "^[OH" beginning-of-line
        bindkey "^[[1~" beginning-of-line
        bindkey "^[[7~" beginning-of-line

        # End
        bindkey "''${terminfo[kend]}" end-of-line 2>/dev/null
        bindkey "^[[F" end-of-line
        bindkey "^[OF" end-of-line
        bindkey "^[[4~" end-of-line
        bindkey "^[[8~" end-of-line

        # Ctrl+Left / Ctrl+Right: word-by-word cursor movement
        bindkey "^[[1;5C" forward-word
        bindkey "^[[1;5D" backward-word
        bindkey "^[[5C" forward-word
        bindkey "^[[5D" backward-word
        bindkey "^[Oc" forward-word # rxvt
        bindkey "^[Od" backward-word # rxvt
      ''
      ''
        # Worktrunk shell integration.
        if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
      ''
    ];
  };

  programs.bash = {
    enable = true;
    initExtra = lib.mkMerge [
      ''
        # Worktrunk shell integration.
        if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
      ''
    ];
  };

  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
      buffer_editor = "hx";
    };
    extraConfig =
      let
        completionDir = "${pkgs.nu_scripts}/share/nu_scripts/custom-completions";
        completions = [
          "git"
          "zellij"
          "mask"
        ];
      in
      lib.concatMapStringsSep "\n" (
        completion: "source ${completionDir}/${completion}/${completion}-completions.nu"
      ) completions
      + "\n\n# Worktrunk shell integration\n"
      + "if (which wt | is-not-empty) { mkdir ($nu.default-config-dir | path join vendor/autoload); wt config shell init nu | save --force ($nu.default-config-dir | path join vendor/autoload/wt.nu) }";
  };

  programs.carapace.enable = true;

  programs.starship.enable = true;
}
