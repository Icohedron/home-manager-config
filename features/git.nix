# Git, including optional SSH commit signing.
#
# The diff pager it uses lives in ./delta.nix.
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
            # Without this, `git log --show-signature` and `git verify-commit`
            # error out instead of verifying. Generated below on activation.
            gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          })
        ];
        signing.format = null;
      };

      # ~/.ssh/allowed_signers maps our email to our public key so ssh
      # signatures made by that key verify. The key lives outside the store,
      # so it is read at activation time rather than at evaluation time.
      home.activation = lib.mkIf commitSigning.enable {
        gitAllowedSigners = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          keyFile="${commitSigning.key}"
          keyFile="''${keyFile/#\~/$HOME}"
          if [ -r "$keyFile" ]; then
            run mkdir -p -m 700 "$HOME/.ssh"
            run install -m 600 \
              <(printf '%s namespaces="git" %s\n' \
                ${lib.escapeShellArg gitEmail} "$(cat "$keyFile")") \
              "$HOME/.ssh/allowed_signers"
          else
            warnEcho "git: $keyFile is missing, skipping ~/.ssh/allowed_signers"
          fi
        '';
      };
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.git ];
}
