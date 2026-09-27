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
          # Sign only our unsigned, mutable commits at `jj git push`, not on
          # every edit/rebase. Without a key, leave signing unconfigured.
          (lib.mkIf commitSigning.enable {
            signing = {
              behavior = "drop";
              backend = "ssh";
              key = commitSigning.key;
            };
            git.sign-on-push = true;
          })
        ];
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.jujutsu ];
}
