# llama.cpp - local inference server.
#
# The build variant follows the GPU stack declared in system/hardware.nix. The
# pi provider that talks to this server is declared in
# ./pi-coding-agent/models.nix, since it configures pi rather than llama.cpp.
{ config, ... }:
{
  flake.modules.homeManager.llama-cpp =
    { pkgs, ... }:
    let
      backend = config.hardware.gpuBackend;
      llamaCpp =
        # On Darwin the default build already targets Metal, and neither the
        # CUDA nor the Vulkan variant is a sensible choice there.
        if !pkgs.stdenv.hostPlatform.isLinux then
          pkgs.llama-cpp
        else if backend == "cuda" then
          pkgs.llama-cpp.override { cudaSupport = true; }
        else if backend == "vulkan" then
          pkgs.llama-cpp-vulkan
        else
          pkgs.llama-cpp;
    in
    {
      home.packages = [ llamaCpp ];
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.llama-cpp ];
}
