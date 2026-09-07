# keychain - keeps one ssh-agent per login and loads the configured keys into it.
#
# Driven by `user.sshKeys` (declared in system/settings.nix, set in user.nix):
# with no keys declared, keychain is not installed and no shell hook is written.
{ config, ... }:
let
  inherit (config.user) sshKeys;
in
{
  flake.modules.homeManager.keychain =
    { lib, pkgs, ... }:
    let
      loadsKeys = sshKeys != [ ];
      keychainEval = shell: ''
        eval "$(SHELL=${shell} ${pkgs.keychain}/bin/keychain --eval --quiet ${lib.escapeShellArgs sshKeys})"
      '';
    in
    {
      programs.keychain = {
        enable = loadsKeys;
        enableBashIntegration = true;
        enableNushellIntegration = true;
        enableZshIntegration = true;
        keys = sshKeys;
      };

      # Start (or reuse) an agent holding the keys before anything else in the
      # shell needs them - Git and Jujutsu sign every commit with one.
      programs.zsh.initExtra = lib.mkIf loadsKeys (lib.mkBefore (keychainEval "zsh"));
      programs.bash.initExtra = lib.mkIf loadsKeys (lib.mkBefore (keychainEval "bash"));
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.keychain ];
}
