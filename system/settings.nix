# Personal settings for this machine, read from ../user.nix.
#
# ../user.nix is the only file you have to edit to adopt this configuration.
# Everything it may declare is described (and defaulted) here, so omitted keys
# fall back to the values below instead of failing to evaluate.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.user = {
    username = mkOption {
      type = types.str;
      description = "Login name of the user this configuration is built for.";
    };

    homeDirectory = mkOption {
      type = types.str;
      default = "/home/${config.user.username}";
      defaultText = "/home/\${config.user.username}";
      description = "Absolute path of the user's home directory.";
    };

    gitUsername = mkOption {
      type = types.str;
      description = "Author name recorded in Git and Jujutsu commits.";
    };

    gitEmail = mkOption {
      type = types.str;
      description = "Author email recorded in Git and Jujutsu commits.";
    };

    useWayland = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the graphical session is Wayland rather than X11.
        Consumed by system/hardware.nix.
      '';
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "id_ed25519"
        "work_ed25519"
      ];
      description = ''
        Private SSH keys that keychain loads into the ssh-agent at shell
        startup. Each entry is either a file name relative to ~/.ssh or an
        absolute path.

        Empty by default: with no keys declared, features/ssh does not enable
        keychain at all, so a machine without SSH keys never pays for it (and
        never sees keychain complain about a missing key at every prompt).
      '';
    };

    commitSigning = {
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "~/.ssh/id_ed25519.pub";
        description = ''
          Key Git and Jujutsu sign commits with: the *public* half of an SSH
          key, usually the `.pub` file belonging to one of `user.sshKeys`.

          `null` (the default) means no signing key exists on this machine,
          which also leaves signing switched off - neither tool is told about a
          key it cannot read.

          Consumed by features/git and features/jujutsu.
        '';
      };

      enable = mkOption {
        type = types.bool;
        default = config.user.commitSigning.key != null;
        defaultText = "whether user.commitSigning.key is set";
        description = ''
          Sign every Git and Jujutsu commit. Turns itself on as soon as a key
          is configured; set it to false to keep the key declared but stop
          signing.
        '';
      };
    };

    llamaCppGPUBackend = mkOption {
      type = types.enum [
        "cuda"
        "vulkan"
        "cpu"
      ];
      default = "vulkan";
      description = ''
        GPU backend llama.cpp is built against.
        Consumed by system/hardware.nix.
      '';
    };

    npmRegistry = mkOption {
      type = types.str;
      default = "https://registry.npmjs.org/";
      description = "npm registry used globally (see features/registries).";
    };

    pypiRegistry = mkOption {
      type = types.str;
      default = "https://pypi.org/simple/";
      description = "PyPI index used globally (see features/registries).";
    };

    nugetRegistry = mkOption {
      type = types.str;
      default = "https://api.nuget.org/v3/index.json";
      description = "NuGet feed used globally (see features/registries).";
    };
  };

  config.user = import ../user.nix;
}
