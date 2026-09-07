# Repository tooling: `nix fmt` and `nix flake check`.
{ config, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # `nixfmt` only formats files, so walk the given paths (the whole
      # repository by default) and hand it every Nix file found.
      formatter = pkgs.writeShellApplication {
        name = "nixfmt-tree";
        runtimeInputs = [
          pkgs.findutils
          pkgs.nixfmt
        ];
        text = ''
          if [ "$#" -eq 0 ]; then
            set -- .
          fi
          find "$@" -type f -name '*.nix' -exec nixfmt {} +
        '';
      };

      # Make `nix flake check` actually build the home configuration - the one
      # for the platform being checked, so this stays correct on every system in
      # `systems`.
      checks.homeConfiguration =
        config.flake.homeConfigurations."${config.user.username}@${system}".activationPackage;
    };
}
