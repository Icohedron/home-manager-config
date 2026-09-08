# Zsh, including key bindings that terminals leave unbound by default.
{ config, ... }:
{
  flake.modules.homeManager.zsh =
    { lib, ... }:
    {
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
        ];
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.zsh ];
}
