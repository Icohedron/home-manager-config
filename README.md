# Home Manager Generic Configuration

This repository provides a declarative, reproducible system configuration for Linux systems using [Nix Flakes](https://nixos.wiki/wiki/Flakes) and [Home Manager](https://nix-community.github.io/home-manager/).

## Structure

* `flake.nix`: The entry point defining the inputs (Nixpkgs, Home Manager) and output configurations.
* `user.nix`: A centralized file containing your user details (username, home directory, git configuration, llama.cpp GPU backend, package registries).
* `home.nix`: A thin Home Manager entrypoint that imports the module collection under `modules/home/`.
* `modules/home/`: Self-contained modules grouped by concern (`core`, `shell`, `editors`, `vcs`, `agent-tools`, `llama-cpp`, etc.).
* `maskfile.md`: A task runner for managing the configuration.

## Getting Started

### 1. Install Nix
If you haven't already, install the Nix package manager. We recommend the [Determinate Systems Nix installer](https://github.com/DeterminateSystems/nix-installer) for a fast and reliable setup with flakes, lazy trees, and other nice features enabled by default. Otherwise, install Nix from the official [NixOS website](https://nixos.org/download/).

### 2. Prepare Environment
Open a temporary shell with `git` and `home-manager` to clone the repository and authenticate if necessary:

```bash
nix-shell -p home-manager git
```

### 3. Clone and Configure
Clone this repository to a directory of your choice (e.g., `~/nix`):

```bash
git clone https://github.com/Icohedron/Home-Manager-Config.git ~/nix
cd ~/nix
```

**Important:** Before applying the configuration, you must update `user.nix` with your specific details. Only `username`, `gitUsername`, and `gitEmail` are required; every other key is optional and falls back to the default declared in `flake.nix`:

```nix
# Edit ~/nix/user.nix
{
  username = "your-username";
  homeDirectory = "/home/your-username"; # Optional. Defaults to /home/<username>

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
```

To prevent accidentally committing your personal details, we highly recommend telling git to ignore changes to this file:

```bash
git update-index --assume-unchanged user.nix
```

> [!IMPORTANT]
> Because `--assume-unchanged` hides edits from git, Nix's evaluation cache
> won't notice when you change `user.nix` and may keep applying a stale
> configuration (for example, `nix flake check` failing on an old username).
> After editing `user.nix`, run your Nix command with `--no-eval-cache` to
> bypass the stale cache:
>
> ```bash
> nix flake check --no-eval-cache
> ```

*Note: If your system's username matches the `username` in `user.nix`, Home Manager will automatically find and apply your configuration.*

### 4. Apply Configuration
Once configured, you can build and switch to your new Home Manager environment:

```bash
home-manager switch --flake . --experimental-features 'nix-command flakes'
```

## Managing Your Setup (using `mask`)

Once installed, your environment includes a task runner called `mask`. You can use it to easily manage your configuration. Simply run `mask` in your `~/nix` directory to see available commands:

* `mask build` - Rebuild and apply the current configuration.
* `mask check` - Dry-run build and evaluate the flake to ensure there are no errors.
* `mask format` - Formats all Nix files in the repository using `nixfmt`.
* `mask update` - Update `flake.lock` with the latest package versions.
* `mask clean` - Run the Nix garbage collector to free up disk space.

## Local Models with llama.cpp

`modules/home/llama-cpp.nix` runs [llama.cpp](https://github.com/ggml-org/llama.cpp)
as a systemd user service in *router mode*, so a single OpenAI-compatible
endpoint on `http://127.0.0.1:8080` can load and unload models on demand.

Models are declared in an INI preset generated from Nix. Each section becomes a
router-visible model id, and each key is a `llama-server` flag without its
leading dashes. The preset currently ships one model:

| | |
|---|---|
| Model id | `Qwen3.6-35B-A3B` |
| Weights | [`unsloth/Qwen3.6-35B-A3B-GGUF`](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF), quantization `UD-Q3_K_XL` (~16.9 GB) |
| Context window | 262144 tokens (256K, the model's native maximum) |
| KV cache | `q8_0` with flash attention (~2.6 GB at full context) |
| VRAM budget | 12 GB |

About 91% of this model is mixture-of-experts weight, so it does not fit in
12 GB at any quantization. The preset instead spends VRAM on the KV cache and
the dense layers and lets llama.cpp's `--fit` logic overflow expert tensors into
system RAM; only ~3B parameters are active per token, so CPU-side experts stay
workable. That also means the quantization is bounded by system RAM rather than
VRAM — `UD-Q4_K_XL` (~22.4 GB) is the upgrade if there is RAM to spare.

> [!IMPORTANT]
> The preset pins `ctx-size` explicitly, and that is load-bearing. llama.cpp
> only auto-shrinks the context to fit VRAM when it was left unset, so removing
> that line would silently give you a 4096-token window instead of offloading
> more weights.

Weights are **not** downloaded at build time. The router fetches them from
Hugging Face into `~/.cache/llama.cpp` the first time the model is requested,
and releases the memory again after 15 idle minutes. Expect the first request to
take a while.

Useful commands:

```bash
mask llama status     # service state and the model ids the router advertises
mask llama logs       # load/download progress
mask llama download   # fetch the weights ahead of time, with a progress bar
mask llama start|stop|restart
```

Every model is declared in the module's preset and pulled with `hf-repo`;
there is no scan directory. Note that llama.cpp separately auto-registers
anything already sitting in `~/.cache/llama.cpp`, so `/v1/models` lists the
cached weights a second time under their bare `repo:quant` id. Only the
preset id (`Qwen3.6-35B-A3B`) carries the tuning described above — the
auto-registered entry loads with llama.cpp defaults, including a far smaller
context window.

> [!NOTE]
> The llama.cpp package is built for the backend named by `llamaCppGPUBackend`
> in `user.nix`: `"cuda"` builds `pkgs.llama-cpp` with `cudaSupport`, `"vulkan"`
> uses `pkgs.llama-cpp-vulkan`, and anything else (`"cpu"`) is the plain CPU
> build. Every variant silently falls back to CPU-only inference when no usable
> device is visible; check with `llama-server --list-devices`.
>
> Pick `"vulkan"` only where a native Vulkan driver exists. Inside a container
> that means `/dev/dri` must be passed through and readable, and under WSL2 the
> NVIDIA driver ships no Vulkan ICD at all, so the only Vulkan device is Mesa's
> non-conformant Dozen (Vulkan-on-D3D12) layer — use `"cuda"` there.
>
> On non-NixOS hosts a CUDA build also needs `libcuda.so.1` on the loader path,
> because Nix's glibc ignores the system `/etc/ld.so.cache`. Under WSL2 the
> driver lives in `/usr/lib/wsl/lib`.

### Using the model from Pi

The same module registers the model with Pi Coding Agent by merging a provider
into `programs.pi-coding-agent.models`, which Home Manager writes to
`~/.pi/agent/models.json`. Select it in Pi with `/model` and pick
**Qwen3.6 35B A3B (local llama.cpp)**.

`LLAMA_BASE_URL` is exported as well, so Pi's built-in `/llama` command can list,
load, unload, and download router models without running `/login llama.cpp`
first.

## Using Zsh

This configuration installs and configures [Zsh](https://www.zsh.org/) (the Z shell) via Home Manager. Zsh is a powerful, interactive Unix shell that is broadly compatible with Bash while adding conveniences such as smarter tab completion, spelling correction, shared command history, rich globbing, and extensive theming/plugin support. Here it comes pre-wired with integrations like Starship (prompt), Carapace (completions), Tirith, and Worktrunk.

Applying the configuration installs Zsh into your environment, but it does **not** automatically make Zsh your login shell. To set Zsh as your default shell, use `chsh` (change shell).

### Set Zsh as your default shell

1. Find the path to the Home Manager-provided Zsh binary:

   ```bash
   which zsh
   ```

2. The shell must be listed in `/etc/shells` before `chsh` will accept it. If the path from the previous step is missing, add it (requires root):

   ```bash
   command -v zsh | sudo tee -a /etc/shells
   ```

3. Change your default shell to Zsh:

   ```bash
   chsh -s "$(which zsh)"
   ```

4. Log out and back in (or open a new terminal session) for the change to take effect. Verify with:

   ```bash
   echo $SHELL
   ```

> [!NOTE]
> On NixOS, the store path to `zsh` changes on updates, which can break a
> `chsh`-set login shell. Prefer setting `users.users.<name>.shell = pkgs.zsh;`
> in your NixOS configuration instead. On non-NixOS systems, `chsh` with the
> path above is the standard approach.
