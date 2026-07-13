# Interactive shell behavior, prompt setup, shell aliases, and shell-specific integrations.
{
  lib,
  pkgs,
  ...
}:
{
  home.shell.enableShellIntegration = true;
  home.shellAliases = {
    grep = "rg";
    cd = "z";
    cdi = "zi";
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
