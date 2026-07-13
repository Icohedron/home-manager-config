# Interactive shell behavior, prompt setup, shell aliases, and shell-specific integrations.
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Upstream tirith (> 0.3.1) includes the bash enter-mode self-test from issue
  # #111, which this setup relies on to verify whether bind -x Enter delivery
  # works on the local bash build.
  tirithPkg = inputs.tirith.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  programs.tirith.enable = true;
  programs.tirith.package = tirithPkg;
  # tirith's enter-mode hook installs a bind -x Enter override plus a
  # PROMPT_COMMAND delivery hook. Starship (mkOrder 1900) hard-replaces
  # PROMPT_COMMAND, so if tirith inits first its hook is clobbered and enter
  # mode degrades to preexec (persisting a safe-mode flag). Disable the
  # module's auto-integration and init tirith last below.
  programs.tirith.enableBashIntegration = false;

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
      # Init tirith LAST — after starship (mkOrder 1900) and zoxide (mkOrder
      # 2000) — so neither clobbers tirith's enter-mode bind/PROMPT_COMMAND hook.
      (lib.mkOrder 3000 ''
        # Silence tirith's per-command "no issues" advisory in preexec warn-only
        # mode. Exported here (not via home.sessionVariables) so it applies in
        # every new interactive shell without a full re-login — hm-session-vars.sh
        # self-guards against re-sourcing. Real DETECTED/warning/block output is
        # unaffected; --quiet only drops clean "no issues" lines, tips, and
        # shadow-binary warnings.
        export TIRITH_QUIET=1
        eval "$(${tirithPkg}/bin/tirith init --shell bash)"
      '')
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
