# lldb - LLVM debugger.
{ config, ... }:
{
  flake.modules.homeManager.lldb =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lldb ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.lldb ];
}
