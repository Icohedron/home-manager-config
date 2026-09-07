# ripgrep (rg) - recursive line-oriented search.
{ config, ... }:
{
  flake.modules.homeManager.ripgrep = {
    programs.ripgrep.enable = true;

    # `grep` is muscle memory; keep it, but let ripgrep answer.
    home.shellAliases.grep = "rg";
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.ripgrep ];
}
