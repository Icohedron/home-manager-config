{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      flake-compat,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      with pkgs;
      {
        # Use magic incantation to enable native compilation with clang & lld
        # Use this magic incantation until https://github.com/NixOS/nixpkgs/issues/142901 is resolved
        devShells.default =
          mkShell.override
            {
              stdenv = overrideCC llvmPackages.stdenv (
                llvmPackages.stdenv.cc.override { inherit (llvmPackages) bintools; }
              );
            }
            {
              name = "rust-env";
              buildInputs = [
                rustc
                cargo
                cargo-xwin
                rustfmt
                rust-analyzer
              ];
            };
      }
    );
}
