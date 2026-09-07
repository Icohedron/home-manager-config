# The Home Manager configurations this repository builds.
#
# `homeConfigurations` is not a per-system flake output, so an attribute name
# has to pin a platform. Rather than declaring which machine this is, one
# configuration is built for every platform in `systems` (see ./nixpkgs.nix):
#
#   homeConfigurations."<user>@<system>"  explicit; always unambiguous
#   homeConfigurations."<user>"           what `home-manager switch --flake .`
#                                         looks up
#
# The bare alias follows `builtins.currentSystem` whenever the flake is
# evaluated impurely (`home-manager switch --flake . --impure`; `mask build`
# selects the qualified name instead, so it needs no impurity). Pure evaluation
# cannot know which machine it runs on, so it falls back to the first supported
# system.
{
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
let
  inherit (config.user) username;

  mkHomeConfiguration =
    system:
    withSystem system (
      { pkgs, ... }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          config.flake.modules.homeManager.core
          config.flake.modules.homeManager.hardware
          config.flake.modules.homeManager.workstation
        ];
      }
    );

  bySystem = lib.genAttrs config.systems mkHomeConfiguration;

  hostSystem =
    if builtins ? currentSystem && lib.elem builtins.currentSystem config.systems then
      builtins.currentSystem
    else
      lib.head config.systems;
in
{
  flake.homeConfigurations =
    lib.mapAttrs' (system: lib.nameValuePair "${username}@${system}") bySystem
    // {
      ${username} = bySystem.${hostSystem};
    };
}
