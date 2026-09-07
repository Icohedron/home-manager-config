# ripgrep-all (rga) - ripgrep over PDFs, archives, office documents and more.
{ config, ... }:
{
  flake.modules.homeManager.ripgrep-all = {
    programs.ripgrep-all.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [
    config.flake.modules.homeManager.ripgrep-all
  ];
}
