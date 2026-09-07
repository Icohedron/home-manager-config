# Jujutsu - Git-compatible VCS, sharing the Git identity and signing setup.
{ config, ... }:
let
  inherit (config.user) gitUsername gitEmail;
  commitSigning = config.user.commitSigning;
in
{
  flake.modules.homeManager.jujutsu =
    { lib, ... }:
    {
      assertions = [
        {
          assertion = !commitSigning.enable || commitSigning.key != null;
          message = ''
            user.commitSigning.enable is true but user.commitSigning.key is null,
            so Jujutsu would be told to sign commits with no key. Set a key in
            user.nix (see system/settings.nix).
          '';
        }
      ];

      programs.jujutsu = {
        enable = true;
        settings = lib.mkMerge [
          {
            user = {
              name = gitUsername;
              email = gitEmail;
            };
            ui.editor = "hx";
          }
          # Without a key, leave jj's signing backend unconfigured entirely.
          (lib.mkIf commitSigning.enable {
            signing = {
              sign-all = true;
              backend = "ssh";
              key = commitSigning.key;
            };
          })
        ];
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.jujutsu ];
}
