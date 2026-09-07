# Git, including optional SSH commit signing.
#
# The diff pager it uses lives in ../delta.
{ config, ... }:
let
  inherit (config.user) gitUsername gitEmail;
  commitSigning = config.user.commitSigning;
in
{
  flake.modules.homeManager.git =
    { lib, ... }:
    {
      assertions = [
        {
          assertion = !commitSigning.enable || commitSigning.key != null;
          message = ''
            user.commitSigning.enable is true but user.commitSigning.key is null,
            so Git would be told to sign commits with no key. Set a key in
            user.nix (see system/settings.nix).
          '';
        }
      ];

      programs.git = {
        enable = true;
        settings = lib.mkMerge [
          {
            user = {
              name = gitUsername;
              email = gitEmail;
            };
            core.editor = "hx";

            merge.conflictstyle = "zdiff3";
          }
          # Only mention a key, and only ask for signatures, when one exists.
          (lib.mkIf commitSigning.enable {
            user.signingkey = commitSigning.key;
            commit.gpgsign = true;
            gpg.format = "ssh";
          })
        ];
        signing.format = null;
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.git ];
}
