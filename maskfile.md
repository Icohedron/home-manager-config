# Commands for managing home-manager

## build

> Rebuilds and applies the home-manager configuration using the current flake.lock

~~~sh
home-manager switch --flake .
~~~

## check

> Performs a dry-run build and evaluates the flake to ensure there are no errors

~~~sh
nix flake check
nix build .#homeConfigurations."$USER".activationPackage --dry-run
~~~

## format

> Formats all Nix files in the repository using nixfmt

~~~sh
find . -type f -name "*.nix" -exec nixfmt {} +
~~~

## update

> Updates flake inputs

~~~sh
nix flake update
~~~

## clean

> Runs the nix garbage collector to remove stale items from the nix store

Refer to [Nix pill
11](https://nixos.org/guides/nix-pills/11-garbage-collector.html) for more
information about how Nix's garbage collector functions. (keywords: GC roots,
/nix/var/nix/gcroots, /nix/store/trash)

~~~sh
nix-collect-garbage --delete-old
~~~

## herdr

> Manages the herdr plugins declared in `modules/home/herdr/plugins`

Herdr plugins are normally installed with `herdr plugin install`, which pulls
whatever upstream currently publishes into herdr's mutable plugin state. Here
they are pinned in Nix instead and registered with `herdr plugin link` during
activation, so updating one means bumping a version or revision and its hashes.

### update

> Bumps the pinned herdr plugins to their latest upstream version

Rewrites the pins in place and prints what changed; nothing is applied until
`mask build`. Both plugin modules are checked, and one that is already current
is left untouched.

The two plugins are pinned differently, so each is handled on its own terms:
reviewr follows its GitHub releases (a tag plus the prebuilt binary's checksum,
taken from the release's `.sha256` sidecar rather than by downloading the
archive), while command-palette has no releases and follows `main`.

Adding a plugin means adding a block here too. Hashes are matched by their exact
current value, so the edits stay correct regardless of where they sit in a file.

~~~sh
set -eu

plugins="modules/home/herdr/plugins"

sri() {
    nix hash convert --hash-algo sha256 --to sri "$1"
}

# reviewr: pinned to a release tag, with a separately pinned release binary.
module="$plugins/reviewr.nix"
current=$(grep -oP '^\s*version = "\K[^"]+' "$module")
latest=$(curl -fsS https://api.github.com/repos/persiyanov/herdr-reviewr/releases/latest |
    jq -r '.tag_name | ltrimstr("v")')

if [ "$current" = "$latest" ]; then
    echo "reviewr: $current (up to date)"
else
    echo "reviewr: $current -> $latest"
    src_hash=$(sri "$(nix-prefetch-url --unpack --type sha256 \
        "https://github.com/persiyanov/herdr-reviewr/archive/refs/tags/v$latest.tar.gz")")
    bin_hash=$(sri "$(curl -fsSL \
        "https://github.com/persiyanov/herdr-reviewr/releases/download/v$latest/herdr-reviewr-x86_64-unknown-linux-musl.sha256" |
        awk '{print $1}')")

    # The source hash comes first in the file, the binary's second.
    old_src=$(grep -oP 'hash = "\K[^"]+' "$module" | sed -n 1p)
    old_bin=$(grep -oP 'hash = "\K[^"]+' "$module" | sed -n 2p)
    sed -i "s|version = \"$current\"|version = \"$latest\"|; s|$old_src|$src_hash|; s|$old_bin|$bin_hash|" "$module"
fi

# command-palette: no releases upstream, so it tracks main.
module="$plugins/command-palette.nix"
current=$(grep -oP '^\s*rev = "\K[^"]+' "$module")
latest=$(curl -fsS https://api.github.com/repos/JanTvrdik/herdr-command-palette/commits/main |
    jq -r '.sha')

if [ "$current" = "$latest" ]; then
    printf 'command-palette: %.7s (up to date)\n' "$current"
else
    printf 'command-palette: %.7s -> %.7s\n' "$current" "$latest"
    hash=$(sri "$(nix-prefetch-url --unpack --type sha256 \
        "https://github.com/JanTvrdik/herdr-command-palette/archive/$latest.tar.gz")")
    old_hash=$(grep -oP 'hash = "\K[^"]+' "$module")
    sed -i "s|$current|$latest|; s|$old_hash|$hash|" "$module"
fi

echo
echo "run 'mask build' to apply"
~~~

## llama

### start

> Starts the llama.cpp server

~~~sh
llama serve -hf "unsloth/Qwen3.6-35B-A3B-GGUF" -c 262144 -cmoe
~~~

### wsl-start

> Starts the llama.cpp server on WSL

~~~sh
LD_LIBRARY_PATH=/usr/lib/wsl/lib llama serve -hf "unsloth/Qwen3.6-35B-A3B-GGUF" -c 262144 -cmoe
~~~

