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

## llama

### start

> Starts the llama.cpp server

~~~sh
llama serve -hf "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL" \
    -c 262144 \
    --temp 0.6 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0.00 \
    --spec-type draft-mtp --spec-draft-n-max 2
~~~

### wsl-start

> Starts the llama.cpp server on WSL

~~~sh
LD_LIBRARY_PATH=/usr/lib/wsl/lib mask llama start
~~~

