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

## update

> Updates the flake.lock to use the latest revisions of inputs such as nixpkgs

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