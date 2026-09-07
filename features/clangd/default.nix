# clangd - C/C++ language server.
#
# clangd is shared by every editor here, so its build and the editor wiring live
# together: ../helix and ../zed-editor stay free of toolchain details, and both
# always point at the exact same clangd.
{ config, ... }:
{
  flake.modules.homeManager.clangd =
    { pkgs, ... }:
    let
      # Use clangd from clang-tools so clangd can find the standard C/C++
      # headers expected by local toolchains.
      clangdPath = "${
        pkgs.llvmPackages_latest.clang-tools.override { enableLibcxx = false; }
      }/bin/clangd";
    in
    {
      # clangd is referenced by absolute store path below, so it is not put on
      # PATH: it would drag clang/clang-tidy into the profile and shadow the
      # host toolchain.
      programs.helix.languages.language-server.clangd.command = clangdPath;
      programs.zed-editor.userSettings.lsp.clangd.binary.path = clangdPath;
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.clangd ];
}
