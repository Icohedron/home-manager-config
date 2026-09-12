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

### login

> Authorises Atuin AI against GitHub Copilot (device flow, once per machine)

Only for `atuinAIBackend = "copilot"`. The llama-cpp backend needs no login -
just `mask llama start`.

Prints a URL and a code, waits for the browser, then restarts the proxy. The
Copilot token it stores under `~/.config/litellm/github_copilot` is refreshed
automatically from then on; run this again if `?` starts answering with an
authentication error.

~~~sh
atuin-ai-login
~~~

### models

> Lists the Copilot model ids this account may use

What `features/atuin/_ai-stack.nix` has to pick from: put any id shown here in
its `models` list, then `mask build`.

~~~sh
token="$(jq -r .token ~/.config/litellm/github_copilot/api-key.json)"
curl -s https://api.githubcopilot.com/models \
    -H "Authorization: Bearer $token" \
    -H "Copilot-Integration-Id: vscode-chat" |
    jq -r '.data[] | select(.capabilities.type == "chat") | .id'
~~~

### restart

> Restarts the Atuin AI services, so `?` works again

Nothing here holds VRAM, so there is nothing to stop for resources' sake - this
is for after a failed login, a lost network, or a llama.cpp server that was
restarted underneath the backend.

~~~sh
systemctl --user restart atuin-ai-server.service
systemctl --user restart atuin-ai-proxy.service 2>/dev/null || true
~~~

### logs

> Follows the Atuin AI services

~~~sh
journalctl --user -u atuin-ai-server.service -u atuin-ai-proxy.service -f
~~~
