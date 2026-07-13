# Home Manager Generic Configuration

This repository provides a declarative, reproducible system configuration for Linux systems using [Nix Flakes](https://nixos.wiki/wiki/Flakes) and [Home Manager](https://nix-community.github.io/home-manager/).

## Structure

* `flake.nix`: The entry point defining the inputs (Nixpkgs, Home Manager) and output configurations.
* `user.nix`: A centralized file containing your user details (username, home directory, git configuration).
* `home.nix`: A thin Home Manager entrypoint that imports the module collection under `modules/home/`.
* `modules/home/`: Self-contained modules grouped by concern (`core`, `shell`, `editors`, `vcs`, `agent-tools`, etc.).
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

**Important:** Before applying the configuration, you must update `users.nix` with your specific details:

```nix
# Edit ~/nix/users.nix
{
  username = "your-username";
  homeDirectory = "/home/your-username"; # Update to your actual home directory
  gitUsername = "Your Name";
  gitEmail = "your.email@example.com";
  useWayland = true;
  npmRegistry = "https://registry.npmjs.org/"; # Per-user npm registry for pi package installs
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
