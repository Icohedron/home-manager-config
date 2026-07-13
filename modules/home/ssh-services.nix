# SSH agent/key management and SSH client defaults.
{ ... }:
{
  programs.keychain = {
    enable = true;
    enableBashIntegration = false;
    enableNushellIntegration = true;
    keys = [ "id_ed25519" ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".addKeysToAgent = "yes";
  };
}
