# worktrunk (`wt`) - Git worktree workflow helper, plus its shell integrations.
#
# The integrations are declared here rather than in the shell features so the
# whole feature can be dropped in or removed as one unit.
{ config, ... }:
{
  flake.modules.homeManager.worktrunk =
    { lib, pkgs, ... }:
    {
      home.packages = [ pkgs.worktrunk ];

      programs.zsh.initContent = lib.mkMerge [
        ''
          # Worktrunk shell integration.
          if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
        ''
      ];

      programs.bash.initExtra = lib.mkMerge [
        ''
          # Worktrunk shell integration.
          if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
        ''
      ];

      programs.nushell.extraConfig = ''

        # Worktrunk shell integration
        if (which wt | is-not-empty) { mkdir ($nu.default-config-dir | path join vendor/autoload); wt config shell init nu | save --force ($nu.default-config-dir | path join vendor/autoload/wt.nu) }'';
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.worktrunk ];
}
