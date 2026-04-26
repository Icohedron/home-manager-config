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

> Updates flake inputs and checks pi packages for newer versions

~~~sh
nix flake update

echo
echo "Checking for pi package updates..."
echo

for SPEC in $(sed -n '/# pi-pkgs/,/]/p' home.nix | grep -oP '"[^"]+"' | tr -d '"'); do
  PKG="${SPEC%@*}"
  CUR_VER="${SPEC##*@}"
  LATEST=$(curl -sf "https://registry.npmjs.org/$PKG/latest" | jq -r '.version')

  if [ "$CUR_VER" = "$LATEST" ]; then
    echo "  ✓ $PKG $CUR_VER"
  else
    echo "  ↑ $PKG $CUR_VER → $LATEST"
  fi
done

echo
echo "To update: edit the version in home.nix, then run: mask build"
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
