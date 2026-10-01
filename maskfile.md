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
automatically from then on. Run this again if `?` stops working because GitHub
revoked the stored authorization; re-login forces a fresh device flow.

~~~sh
atuin-ai-login
~~~

### status

> Shows whether the Atuin AI server and LiteLLM proxy are running, and checks GitHub Copilot authorization

The auth check exchanges the stored OAuth token with GitHub; it does not make a
model request or print the token. On the llama-cpp backend, Copilot auth is not
required.

~~~sh
for service in atuin-ai-server atuin-ai-proxy; do
    case "$service" in
        atuin-ai-server) label='Atuin AI server' ;;
        atuin-ai-proxy) label='LiteLLM' ;;
    esac
    if systemctl --user is-active --quiet "$service.service"; then
        printf '%s: running\n' "$label"
    elif systemctl --user cat "$service.service" --no-pager >/dev/null 2>&1; then
        printf '%s: not running\n' "$label"
    else
        printf '%s: not configured\n' "$label"
    fi
done

if ! systemctl --user cat atuin-ai-proxy.service --no-pager >/dev/null 2>&1; then
    echo 'Copilot auth: not required (no LiteLLM proxy)'
else
    token_file="$HOME/.config/litellm/github_copilot/access-token"
    if [ ! -s "$token_file" ]; then
        echo 'Copilot auth: missing (run mask atuin login)'
    else
        # Pass the header on stdin, not in curl's process arguments or output.
        oauth_token="$(cat "$token_file")"
        if [ -z "$oauth_token" ]; then
            echo 'Copilot auth: missing (run mask atuin login)'
        elif code="$(printf 'Authorization: token %s\n' "$oauth_token" |
            curl --silent --output /dev/null --write-out '%{http_code}' \
                --max-time 10 --header @- \
                https://api.github.com/copilot_internal/v2/token 2>/dev/null)"; then
            case "$code" in
                200) echo 'Copilot auth: valid (GitHub accepted the token)' ;;
                401) echo 'Copilot auth: expired or revoked (run mask atuin login)' ;;
                *)   printf 'Copilot auth: unknown (GitHub HTTP %s)\n' "$code" ;;
            esac
        else
            echo 'Copilot auth: unknown (cannot reach GitHub)'
        fi
    fi
fi
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

> Restarts LiteLLM (when configured) and the Atuin AI server, so `?` works again

Nothing here holds VRAM, so there is nothing to stop for resources' sake - this
is for after a failed login, a lost network, or a llama.cpp server that was
restarted underneath the backend. A stale LiteLLM process can survive a unit
restart and hold port 8082; only processes in that service's cgroup are killed.

~~~sh
if systemctl --user cat atuin-ai-proxy.service --no-pager >/dev/null 2>&1; then
    systemctl --user stop atuin-ai-proxy.service || exit $?
    # A leftover process may still own 8082 even though the unit has stopped.
    for cgroup in /proc/[0-9]*/cgroup; do
        if grep -Eq '/atuin-ai-proxy[.]service$' "$cgroup" 2>/dev/null &&
            grep -aq litellm "${cgroup%/cgroup}/cmdline" 2>/dev/null; then
            pid="${cgroup%/cgroup}"
            pid="${pid##*/}"
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    for attempt in 1 2 3 4 5; do
        listeners="$(ss -H -ltn 'sport = :8082')" || exit $?
        [ -z "$listeners" ] && break
        sleep 1
    done
    listeners="$(ss -H -ltn 'sport = :8082')" || exit $?
    if [ -n "$listeners" ]; then
        echo 'Port 8082 is still in use; refusing to start LiteLLM.' >&2
        exit 1
    fi
    systemctl --user start atuin-ai-proxy.service || exit $?
fi
systemctl --user restart atuin-ai-server.service
~~~

### update

> Pulls the newest Atuin AI server image and restarts the services

`mask atuin restart` alone reuses the locally cached `:latest` image. This task
pulls it first; if the pull fails, the running services are left untouched.

~~~sh
podman pull ghcr.io/atuinsh/atuin-ai-server:latest && mask atuin restart
~~~

### logs

> Follows the Atuin AI services

~~~sh
journalctl --user -u atuin-ai-server.service -u atuin-ai-proxy.service -f
~~~
