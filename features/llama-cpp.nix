# llama.cpp - local inference server.
#
# The build variant follows the GPU stack declared in system/hardware.nix. The
# pi provider that talks to this server is declared in
# ./pi-coding-agent/models.nix, since it configures pi rather than llama.cpp.
{ config, ... }:
let
  backend = config.hardware.gpuBackend;
in
{
  # Published as a flake output, like the modules themselves, so that anything
  # which has to *run* llama.cpp - the Atuin AI model service in
  # ./atuin/ai.nix - gets the same build without repeating the choice below.
  # A function of `pkgs`, because the variant can only be picked once the
  # platform's package set exists.
  flake.lib.llamaCppFor =
    pkgs:
    # On Darwin the default build already targets Metal, and neither the CUDA
    # nor the Vulkan variant is a sensible choice there.
    if !pkgs.stdenv.hostPlatform.isLinux then
      pkgs.llama-cpp
    else if backend == "cuda" then
      pkgs.llama-cpp.override { cudaSupport = true; }
    else if backend == "vulkan" then
      pkgs.llama-cpp-vulkan
    else
      pkgs.llama-cpp;

  flake.modules.homeManager.llama-cpp =
    { pkgs, ... }:
    {
      home.packages = [ (config.flake.lib.llamaCppFor pkgs) ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.llama-cpp ];
}
