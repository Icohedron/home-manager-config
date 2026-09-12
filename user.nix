{
  username = "your-username";
  homeDirectory = "/home/your-username"; # Optional. Defaults to /home/<username>

  gitUsername = "Your Name";
  gitEmail = "your.email@example.com";

  # Optional. Private SSH keys keychain loads into the ssh-agent at shell
  # startup (see features/ssh). Names are relative to ~/.ssh; absolute paths
  # also work. Defaults to [ ], which leaves keychain disabled entirely.
  sshKeys = [ "id_ed25519" ];

  # Optional. Commit signing for Git and Jujutsu (see features/git,
  # features/jujutsu). Declaring a key switches signing on; add
  # `enable = false;` to keep the key but stop signing. Defaults to no key,
  # and therefore no signing at all.
  commitSigning.key = "~/.ssh/id_ed25519.pub";

  # Whether to use wayland or x11 applications
  useWayland = true; # Optional. Defaults to true

  # Optional. GPU backend llama.cpp is built against (see system/hardware.nix):
  #   "cuda"   - NVIDIA GPU, builds llama.cpp with cudaSupport
  #   "vulkan" - any GPU with a native Vulkan driver (default)
  #   "cpu"    - no GPU offload
  llamaCppGPUBackend = "vulkan";

  # Optional. Whether Atuin's `?` key gets a self-hosted Atuin AI backend (see
  # features/atuin). Two user services, answered by GitHub Copilot - run
  # `atuin-ai-login` once to authorise it. Defaults to false, which leaves the
  # shell history alone.
  atuinAI = true;

  # Optional. Which engine answers Atuin AI:
  #   "copilot"   - GitHub Copilot, via a local LiteLLM proxy (default)
  #   "llama-cpp" - the llama.cpp server from `mask llama start`, port 8080
  atuinAIBackend = "copilot";

  # Optional per-user package registries (see features/registries).
  # Omit any of them to keep the public defaults shown here.
  npmRegistry = "https://registry.npmjs.org/";
  pypiRegistry = "https://pypi.org/simple/";
  nugetRegistry = "https://api.nuget.org/v3/index.json";
}
