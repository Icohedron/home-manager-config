# Cross-shell defaults: which shells get program integrations wired in.
#
# Individual shells live in ../zsh, ../bash and ../nushell; per-program aliases
# and snippets live with the program that owns them (e.g. ../zoxide, ../ripgrep,
# ../worktrunk).
{ config, ... }:
{
  flake.modules.homeManager.shell = {
    home.shell.enableShellIntegration = true;
    home.shell.enableNushellIntegration = true;
    home.shell.enableZshIntegration = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.shell ];
}
