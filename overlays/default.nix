{ inputs, ... }@args:
{
  # When applied, the stable nixpkgs set (declared in the flake inputs) will be accessible through 'pkgs.stable'
  stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # Repairs bun-compiled binaries with out-of-order PT_LOAD headers, which
  # segfault inside ld.so under glibc >= 2.41. See the file for details.
  elf-phdr-order = import ./elf-phdr-order.nix args;
}
