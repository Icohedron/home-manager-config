# Interactive shell behavior, prompt setup, shell aliases, and shell-specific integrations.
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Upstream tirith includes the bash enter-mode self-test needed for the local setup.
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
        # Skip keychain inside sandbox — reuse the inherited SSH_AUTH_SOCK instead.
        if [[ -z "$SANDBOX" ]]; then
          eval "$(SHELL=bash ${pkgs.keychain}/bin/keychain --eval --quiet id_ed25519)"
        fi

        # Worktrunk shell integration.
        if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
      ''
      (lib.mkOrder 3000 ''
        # Initialize tirith last so later prompt integrations do not clobber its
        # enter-mode bind/PROMPT_COMMAND hook.
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

  programs.starship = {
    enable = true;
    settings = {
      env_var.SANDBOX = {
        style = "bold red";
        variable = "SANDBOX";
        format = "[\\[sandbox\\] ]($style)";
      };
    };
  };
}
