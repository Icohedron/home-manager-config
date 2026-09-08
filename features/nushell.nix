# Nushell, with third-party completions from nu_scripts.
{ config, ... }:
{
  flake.modules.homeManager.nushell =
    { lib, pkgs, ... }:
    {
      programs.nushell = {
        enable = true;
        settings = {
          show_banner = false;
          buffer_editor = "hx";
        };
        extraConfig =
          let
            completionDir = "${pkgs.nu_scripts}/share/nu_scripts/custom-completions";
            completions = [
              "git"
              "zellij"
              "mask"
            ];
          in
          lib.concatMapStringsSep "\n" (
            completion: "source ${completionDir}/${completion}/${completion}-completions.nu"
          ) completions;
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.nushell ];
}
