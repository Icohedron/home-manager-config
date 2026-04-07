# Home Manager Generic Configuration

This repository provides a declarative, reproducible system configuration for Linux systems using [Nix Flakes](https://nixos.wiki/wiki/Flakes) and [Home Manager](https://nix-community.github.io/home-manager/).

## Structure

* `flake.nix`: The entry point defining the inputs (Nixpkgs, Home Manager) and output configurations.
* `users.nix`: A centralized file containing your user details (username, home directory, git configuration).
* `home.nix`: The core Home Manager module containing all your packages, CLI utilities, and program settings.
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
[
  {
    username = "your-username";
    homeDirectory = "/home/your-username"; # Update to your actual home directory
    gitUsername = "Your Name";
    gitEmail = "your.email@example.com";
    useWayland = true;
  }
]
```

To prevent accidentally committing your personal details, we highly recommend telling git to ignore changes to this file:

```bash
git update-index --assume-unchanged users.nix
```

*Note: If your system's username matches the `username` in `users.nix`, Home Manager will automatically find and apply your configuration.*

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
