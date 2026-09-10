# Commands for managing home-manager

## build

> Rebuilds and applies the home-manager configuration using the current flake.lock

~~~sh
system="$(nix eval --raw --impure --expr builtins.currentSystem)"
home-manager switch --flake ".#$USER@$system"
~~~

## check

> Performs a dry-run build and evaluates the flake to ensure there are no errors

~~~sh
system="$(nix eval --raw --impure --expr builtins.currentSystem)"
nix flake check
nix build ".#homeConfigurations.\"$USER@$system\".activationPackage" --dry-run
~~~

## format

> Formats all Nix files in the repository using nixfmt (via the flake formatter)

~~~sh
nix fmt
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

## atuin

### start

> Starts the local model behind Atuin AI, so `?` works again

The model is loaded from the Hugging Face cache, which takes a few seconds; the
unit is up before the server is ready to answer. Watch it come up with
`journalctl --user -u atuin-ai-model.service -f` and wait for the line about
listening.

~~~sh
systemctl --user start atuin-ai-model.service
~~~

### stop

> Stops that model, releasing the VRAM (or RAM) it holds

Only the llama.cpp server from features/atuin/ai.nix - the one serving
MiniCPM5 on port 8082. `mask llama start` is a different server, and
atuin-ai-server keeps running: it costs nothing idle, and it is what the `?`
key talks to.

Atuin AI stays unusable until `mask atuin start`, since the backend has no
model to reach. Note that anything which (re)starts atuin-ai-server brings the
model back up with it - `Wants=atuin-ai-model.service` - including a
`mask build` that changes the backend's unit.

~~~sh
systemctl --user stop atuin-ai-model.service
~~~

