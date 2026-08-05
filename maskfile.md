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

> Manages the local llama.cpp inference server

The server runs as the `llama-server` systemd user service declared in
`modules/home/llama-cpp.nix`, and is started automatically on login. These
commands are for the cases where you need to intervene by hand.

Note that starting the service does not load a model: the preset sets
`load-on-startup = false`, so weights are fetched and loaded on the first
request and released again after 15 idle minutes.

### start

> Starts the llama.cpp server

~~~sh
systemctl --user start llama-server
~~~

### stop

> Stops the llama.cpp server, unloading any resident model

~~~sh
systemctl --user stop llama-server
~~~

### restart

> Restarts the llama.cpp server

Changes to the preset normally arrive via `mask build`, which restarts the
service as part of activation, so this is mostly for clearing a wedged server
or forcing a resident model to be unloaded.

~~~sh
systemctl --user restart llama-server
~~~

### status

> Shows the service state and the model ids the router is advertising

~~~sh
systemctl --user status llama-server --no-pager || true
echo
if models=$(curl -fsS http://127.0.0.1:8080/v1/models 2>/dev/null); then
    echo "$models" | jq -r '.data[].id'
else
    echo "router is not responding on 127.0.0.1:8080"
fi
~~~

### logs

> Follows the server log, which is where model download and load progress appears

~~~sh
journalctl --user -u llama-server -n 50 -f
~~~

### download

> Fetches the model weights ahead of time, with a progress bar

Entirely optional: the router downloads on demand, so the only thing this
buys is not having the first request block for ~17.8 GB with no visible
progress.

The repository and quantization are read out of `modules/home/llama-cpp.nix`
rather than repeated here, so switching quantization stays a one-line change
in the Nix module.

Weights land in `~/.cache/llama.cpp`, which is the same cache the service
passes to `llama-server` via `LLAMA_CACHE`, and the vision projector is
pulled alongside them. Re-running is safe: cached files are revalidated
against their stored etag and skipped when current.

`LLAMA_CACHE` is set explicitly below rather than relying on llama.cpp's
default, which derives the cache from `XDG_CACHE_HOME`. The service pins the
cache path, so leaving this to `XDG_CACHE_HOME` would let the two diverge and
quietly download the same 17.8 GB twice.

The progress bar is written to stdout only when it is a terminal (see
`is_output_a_tty` in llama.cpp's `common/download.cpp`), so piping or
redirecting this task silently loses it.

~~~sh
module="modules/home/llama-cpp.nix"
export LLAMA_CACHE="$HOME/.cache/llama.cpp"

if ! command -v llama > /dev/null; then
    echo "llama is not on PATH; run 'mask build' first" >&2
    exit 1
fi

repo=$(grep -oP '^\s*repo = "\K[^"]+' "$module")
quant=$(grep -oP '^\s*quant = "\K[^"]+' "$module")

if [ -z "$repo" ] || [ -z "$quant" ]; then
    echo "could not read repo/quant from $module" >&2
    exit 1
fi

echo "Downloading $repo:$quant"
llama download -hf "$repo:$quant"
~~~
