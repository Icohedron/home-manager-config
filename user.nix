{
  username = "your-username";
  homeDirectory = "/home/your-username"; # Optional. Defaults to /home/<username>.

  gitUsername = "Your Name";
  gitEmail = "your.email@example.com";

  # Whether to use wayland or x11 applications
  useWayland = true; # Optional. Defaults to true

  # Optional. GPU backend llama.cpp is built against (see modules/home/agent-tools.nix):
  #   "cuda"   - NVIDIA GPU, builds llama.cpp with cudaSupport
  #   "vulkan" - any GPU with a native Vulkan driver (default)
  #   "cpu"    - no GPU offload
  llamaCppGPUBackend = "vulkan";

  # Optional per-user package registries (see modules/home/registries.nix).
  # Omit any of them to keep the public defaults shown here.
  npmRegistry = "https://registry.npmjs.org/";
  pypiRegistry = "https://pypi.org/simple/";
  nugetRegistry = "https://api.nuget.org/v3/index.json";
}
