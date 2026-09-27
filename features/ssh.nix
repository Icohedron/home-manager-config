# ssh - OpenSSH client and optional agent handoff configuration.
#
# Install OpenSSH regardless of whether keys are declared. Only manage
# ~/.ssh/config when `user.sshKeys` is nonempty (see ./keychain.nix), so
# machines without declared keys retain their hand-written SSH config.
{ config, ... }:
let
  inherit (config.user) sshKeys;
in
{
  flake.modules.homeManager.ssh =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.openssh ];

      programs.ssh = {
        enable = sshKeys != [ ];
        enableDefaultConfig = false;
        settings."*".addKeysToAgent = "yes";
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.ssh ];
}
