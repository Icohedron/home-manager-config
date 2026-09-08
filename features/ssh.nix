# ssh - OpenSSH client configuration.
#
# No package is installed: `programs.ssh.package` stays null, so the ssh binary
# comes from the system and this feature only owns ~/.ssh/config.
#
# The only thing configured is the agent handoff, so the whole client config
# follows `user.sshKeys` (see ./keychain.nix). With no keys declared, Home Manager
# does not manage ~/.ssh/config at all - it would otherwise replace a
# hand-written config with an empty one.
{ config, ... }:
let
  inherit (config.user) sshKeys;
in
{
  flake.modules.homeManager.ssh = {
    programs.ssh = {
      enable = sshKeys != [ ];
      enableDefaultConfig = false;
      settings."*".addKeysToAgent = "yes";
    };
  };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.ssh ];
}
