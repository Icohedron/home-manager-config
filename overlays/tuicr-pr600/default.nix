# Pin `tuicr` to the source of agavra/tuicr#600 ("Fix/552 comment highlight perf")
# instead of the released version packaged in nixpkgs.
#
# The PR memoizes markdown highlighting of comment bodies and culls comment
# boxes outside the viewport, which is the dominant per-frame cost in a review
# that has comments in it.
#
# WHAT IS PINNED
#   agavra/tuicr#600 is an *open draft* PR whose head lives in a fork
#   (joshvito/tuicr). Forks are rewritable: a branch name is not a stable
#   identity, so this pins the exact commit rather than the branch. Re-point
#   `rev`/`hash` deliberately to pick up new work on the PR.
#
#   Commit 855c55d0 is the head of `fix/552-comment-highlight-perf` and is
#   `agavra/tuicr` `main` + 7 commits, 0 behind. Because it tracks `main` rather
#   than the v0.22.0 tag nixpkgs ships, this is a bigger jump than the PR alone:
#   vs v0.22.0 it is 18 commits / 61 files, of which only 7 commits / 6 files are
#   the PR. The other 11 commits / 57 files are unreleased upstream `main` work
#   (a new summary popup, a diff-parser rewrite, hg/jj changes). Those come from
#   the same upstream author nixpkgs already packages, but they are unreleased
#   and were not part of the review that justified this pin.
#
# WHY THERE IS NO cargoHash
#   The PR does not touch Cargo.toml or Cargo.lock — both are byte-identical to
#   upstream `main` — so the dependency set is unchanged. `Cargo.lock` next to
#   this file is a verbatim copy of the lockfile at the pinned commit, and every
#   one of its 393 packages is a checksummed crates.io entry (no git deps), so
#   `importCargoLock` can derive all fetches from the lockfile itself. That
#   avoids a `cargoHash` that cannot be computed without a full build, and it
#   cannot silently drift: nixpkgs' `cargoSetupPostPatchHook` diffs this
#   lockfile against the one in `src` and fails the build if they differ.
#
# REMOVING THIS
#   Delete this directory, drop the `tuicr-pr600` entries from ../default.nix
#   and ../../modules/home/core.nix, and `pkgs.tuicr` falls back to nixpkgs.
final: prev: {
  tuicr = prev.tuicr.overrideAttrs (old: {
    # Cargo.toml at the pinned commit says 0.22.0, but this is 11 commits past
    # the v0.22.0 tag plus the PR, so use the nixpkgs snapshot convention. This
    # string is user-visible: ../../modules/home/agent-tools.nix bakes it into
    # the generated tuicr SKILL.md, where "unstable" is exactly what a reader
    # should see.
    version = "0.22.0-unstable-2026-08-18";

    src = final.fetchFromGitHub {
      owner = "joshvito";
      repo = "tuicr";
      rev = "855c55d03983753371c489b6ab5bdabf73e6aa1b";
      hash = "sha256-Drv1O8Z0FPq6r5pLWisHnVWtu+l1Mpz6vmjquSagqvc=";
    };

    # Takes precedence over the inherited `cargoHash`, which belongs to the
    # nixpkgs release source and would otherwise be checked against this tree.
    cargoDeps = final.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
    };

    # `versionCheckHook` asserts that `tuicr --version` contains `version`
    # verbatim; the binary reports a plain "0.22.0", so the snapshot suffix
    # above would fail it. The check is redundant here anyway — the upstream
    # `cargo test` suite still runs in checkPhase, including the tests this PR
    # adds for the markdown cache and viewport culling.
    doInstallCheck = false;

    meta = old.meta // {
      # Upstream meta derives this from `src.tag`, which is null now that `src`
      # is pinned by `rev`; left as-is it would fail to evaluate.
      changelog = "https://github.com/agavra/tuicr/pull/600";
    };

    # `nix-update-script` would rewrite `version`/`src` back toward an upstream
    # release tag and silently undo this pin.
    passthru = builtins.removeAttrs (old.passthru or { }) [ "updateScript" ];
  });
}
