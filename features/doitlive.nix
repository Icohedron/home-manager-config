# doitlive - scripted live terminal demos.
{ config, ... }:
{
  flake.modules.homeManager.doitlive =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.doitlive ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.doitlive ];
}
