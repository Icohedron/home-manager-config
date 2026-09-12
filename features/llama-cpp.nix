# llama.cpp - local inference server.
#
# The build variant follows the GPU stack declared in system/hardware.nix. The
# pi provider that talks to this server is declared in
# ./pi-coding-agent/models.nix, since it configures pi rather than llama.cpp.
#
# The server itself is started by hand (`mask llama start`), not by a unit: a
# 35B model is not something to keep resident by accident.
{ config, ... }:
let
  backend = config.hardware.gpuBackend;
in
{
  # Where that server listens and what it serves, published so the things
  # which *talk* to it - pi's provider, and Atuin AI when
  # `user.atuinAIBackend = "llama-cpp"` - agree with the command line in
  # ../maskfile.md without repeating it.
  flake.lib.llamaCppServer = {
    port = 8080;

    model = {
      # What `llama serve -hf <id>` was given, and so the only name this
      # server answers to.
      id = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
      name = "Unsloth Qwen3.6-35B-A3B MTP (UD-Q4_K_XL)";

      # 262144 token context size: the native context length of Qwen3.6.
      contextWindow = 262144;
    };
  };
  # Published as a flake output, like the modules themselves, so that anything
  # which has to *run* llama.cpp gets the same build without repeating the
  # choice below. A function of `pkgs`, because the variant can only be picked
  # once the platform's package set exists.
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
