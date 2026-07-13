# Home Manager module collection.
#
# Each imported file owns one coherent area of the configuration so changes stay
# easy to find, review, and reason about.
{ ... }:
{
  imports = [
    ./core.nix
    ./base-packages.nix
    ./agent-tools.nix
    ./shell.nix
    ./cli-tools.nix
    ./vcs.nix
    ./editors.nix
    ./ssh-services.nix
  ];
}
