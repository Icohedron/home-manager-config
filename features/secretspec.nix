# secretspec - declarative secrets, every environment, any provider.
#
# `programs.secretspec.settings` also manages
# `$XDG_CONFIG_HOME/secretspec/config.toml`; leaving it empty keeps whatever
# `secretspec config init` writes there.
{ config, ... }:
{
  flake.modules.homeManager.secretspec = {
    programs.secretspec.enable = true;
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.secretspec ];
}
