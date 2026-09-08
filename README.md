# Home Manager Generic Configuration

This repository provides a declarative, reproducible system configuration for Linux systems using [Nix Flakes](https://nixos.wiki/wiki/Flakes), [flake-parts](https://flake.parts) and [Home Manager](https://nix-community.github.io/home-manager/).

It follows the [dendritic pattern](https://github.com/mightyiam/dendritic): **every `.nix` file in the repository is a flake-parts module**, and all of them are imported automatically by [import-tree](https://github.com/denful/import-tree). There is no central list of imports to maintain — creating a file is enough to add it to the configuration.

## Structure

```
flake.nix          entry point: inputs + `import-tree [ ./system ./features ]`
user.nix           your personal details (the only file you must edit)
system/            machine configuration and hardware-specific packages
features/          one self-contained file (or directory) per program
maskfile.md        task runner for managing the configuration
```

### `system/`

| File | Purpose |
|---|---|
| `settings.nix` | Declares the `user.*` options and loads `../user.nix` into them |
| `hardware.nix` | Machine facts Nix can't detect (`hardware.wayland`, `hardware.gpuBackend`) and hardware-specific packages |
| `nixpkgs.nix` | Supported platforms (`systems`) and the package set (`allowUnfree`) every module evaluates against |
| `overlays.nix` | Nixpkgs overlays published by the flake (`pkgs.stable`) |
| `home.nix` | Core Home Manager module: Nix settings, state version, user/home paths |
| `configurations.nix` | Assembles `homeConfigurations` (one per supported platform) from `core`, `hardware` and `workstation` |
| `checks.nix` | `nix fmt` formatter and the `nix flake check` build |

### `features/`

Every entry is **one program** - one binary, one feature. No bundles: `zip`,
`unzip` and `p7zip` are three features, not one "archives" feature, so any of
them can be added or dropped on its own.

Most features need nothing but a single file, so they are one:

```
features/bat.nix
features/ripgrep.nix
features/zip.nix
```

A feature only becomes a directory when it has something to keep next to it -
`import-tree` walks the whole tree, so `default.nix` carries no special meaning
and nesting costs nothing:

```
features/tuicr/            default.nix + config.toml
features/helix/            default.nix + hlsl-queries/*.scm
features/pi-coding-agent/  default.nix, sandbox.nix, integrations.nix, models.nix
```

A feature owns *everything* about its program: the package, its configuration,
its data files, and its integrations with other tools. For example
`features/worktrunk.nix` holds the package *and* its zsh, bash and nushell
snippets, and `features/delta.nix` holds the pager *and* the `[delta]` section
it needs in Git's config.

A few features legitimately install nothing: `features/ssh.nix` only writes
`~/.ssh/config` (the binary comes from the system), `features/clangd.nix` only
points the editors at a language server, and `features/shell.nix` and
`features/registries.nix` are pure configuration.

A feature file looks like this:

```nix
# features/bat.nix
{ config, ... }:
{
  # 1. Publish the feature as a named Home Manager module.
  flake.modules.homeManager.bat = {
    programs.bat.enable = true;
  };

  # 2. Register it in the profile this machine builds.
  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.bat ];
}
```

Because features publish themselves as `flake.modules.homeManager.<name>`, they
are also exported by the flake and can be reused elsewhere. Dropping the second
line keeps a feature in the repository without installing it.

Larger features may split across several files in their directory — they all
extend the same module. See `features/pi-coding-agent/`, which is split into
`default.nix`, `sandbox.nix`, `integrations.nix` and `models.nix`.

Files and directories whose name starts with `_` are ignored by `import-tree`,
so helper data can live next to a feature without being evaluated as a module.

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

**Important:** Before applying the configuration, you must update `user.nix` with your specific details. Only `username`, `gitUsername`, and `gitEmail` are required; every other key is optional and falls back to the default declared in `system/settings.nix`:

```nix
# Edit ~/nix/user.nix
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

  # Optional per-user package registries (see features/registries).
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

#### Platforms

Nothing in this repository declares which machine it is running on — Nix cannot
know that during pure flake evaluation. Instead, `system/nixpkgs.nix` lists the
platforms the configuration supports, and `system/configurations.nix` builds one
configuration for each:

```
homeConfigurations."<user>@x86_64-linux"
homeConfigurations."<user>@aarch64-linux"
homeConfigurations."<user>"              # alias, for `home-manager switch --flake .`
```

The bare alias resolves to `builtins.currentSystem` when the flake is evaluated
impurely, and otherwise falls back to the first supported platform. So on a
non-x86 machine use any of:

```bash
mask build                                   # detects the platform for you
home-manager switch --flake . --impure       # resolves the alias to this machine
home-manager switch --flake .#"$USER@aarch64-linux"
```

Supporting another platform is one line in `system/nixpkgs.nix`; features that
are not portable should gate their packages themselves (this is why `steam-run`,
which pulls in the i686 package set, is not installed).

## Managing Your Setup (using `mask`)

Once installed, your environment includes a task runner called `mask`. You can use it to easily manage your configuration. Simply run `mask` in your `~/nix` directory to see available commands:

* `mask build` - Rebuild and apply the current configuration.
* `mask check` - Evaluate and dry-run build the flake to ensure there are no errors.
* `mask format` - Format every Nix file in the repository (`nix fmt`, which runs `nixfmt`).
* `mask update` - Update `flake.lock` with the latest package versions.
* `mask clean` - Run the Nix garbage collector to free up disk space.

## Adding Things

* **A new program**: create `features/<name>.nix` using the template above,
  named after the binary it installs. Promote it to `features/<name>/` only
  when it needs data files or grows into several modules.
* **A machine-specific choice** (GPU stack, display server): add
  or override an option in `system/hardware.nix` and consume it from the feature
  that cares about it.
* **A new user setting**: declare the option in `system/settings.nix`, then set
  it in `user.nix`.

## Local Models with llama.cpp

`features/llama-cpp/` installs [llama.cpp](https://github.com/ggml-org/llama.cpp),
built for the backend named by `llamaCppGPUBackend` in `user.nix` (surfaced as
`hardware.gpuBackend` in `system/hardware.nix`):

* `"cuda"` builds `pkgs.llama-cpp` with `cudaSupport`
* `"vulkan"` uses `pkgs.llama-cpp-vulkan`
* `"cpu"` is the plain CPU build

The server is started on demand rather than as a service:

```bash
mask llama start       # llama-server with the tuned Qwen3.6 flags
mask llama wsl-start   # same, with the WSL driver path exported
```

Weights are **not** downloaded at build time; `llama-server` fetches them from
Hugging Face into `~/.cache/llama.cpp` on first use, so expect the first request
to take a while.

> [!NOTE]
> Every variant silently falls back to CPU-only inference when no usable device
> is visible; check with `llama-server --list-devices`.
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

`features/pi-coding-agent/models.nix` registers the local endpoint with the Pi
Coding Agent by declaring a `llama.cpp-custom` provider, which Home Manager
writes to `~/.pi/agent/models.json`. Pi's built-in llama.cpp provider reports
every router model as non-reasoning, so the model is declared explicitly there
to enable thinking and vision and to pin the real 262144-token context window.
Select it in Pi with `/model`.

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
