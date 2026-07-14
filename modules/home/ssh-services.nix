# SSH agent/key management and SSH client defaults.
{
  lib,
  pkgs,
  ...
}:
{
  programs.keychain = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    keys = [ "id_ed25519" ];
  };

  programs.zsh.initExtra = lib.mkBefore ''
    eval "$(SHELL=zsh ${pkgs.keychain}/bin/keychain --eval --quiet id_ed25519)"
  '';
  programs.bash.initExtra = lib.mkBefore ''
    eval "$(SHELL=bash ${pkgs.keychain}/bin/keychain --eval --quiet id_ed25519)"
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".addKeysToAgent = "yes";
  };
}
