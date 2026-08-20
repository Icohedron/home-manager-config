# Pin `tuicr` to the upstream v0.23.1 release instead of the older release
# packaged in nixpkgs (currently v0.22.0).
#
# v0.23.1 carries the comment-rendering performance work this pin originally
# existed for: agavra/tuicr#600 ("cull comment boxes outside the viewport")
# shipped in 0.23.1 alongside #628 ("parse comment markdown with
# pulldown-cmark"). Both are now release commits on agavra/tuicr, so this is a
# plain version bump rather than the previous fork/draft-PR pin.
#
# HOW TO BUMP
#   Set `version`, blank out both hashes below, build, and paste back the
#   hashes nix reports. Delete this whole directory once nixpkgs ships >=
#   0.23.1: drop the `tuicr-pin` entries from ../default.nix and
#   ../../modules/home/core.nix, and `pkgs.tuicr` falls back to nixpkgs.
final: prev:
let
  version = "0.23.1";

  src = final.fetchFromGitHub {
    owner = "agavra";
    repo = "tuicr";
    tag = "v${version}";
    hash = "sha256-SvRvoQN9b4pXg4rPFnYI2Yeg3SAZKyjYknR2AzfoHnY=";
  };
in
{
  tuicr = prev.tuicr.overrideAttrs {
    # Beyond the store path, `version` drives `src.tag` above, `meta.changelog`
    # (upstream builds it from `finalAttrs.src.tag`), and the `versionCheckHook`
    # assertion that `tuicr --version` matches. All three stay correct because
    # this is a real release tag, so unlike a snapshot pin nothing else in the
    # nixpkgs expression has to be disabled to accommodate it.
    inherit version src;

    # NOT `cargoHash`. `buildRustPackage` is assembled with
    # `extendMkDerivation`, which reads `cargoHash` from the *original*
    # package.nix arguments before `overrideAttrs` is applied, so a `cargoHash`
    # set here is silently ignored: the build would keep vendoring against
    # nixpkgs' v0.22.0 hash, fail, print the correct hash, and then ignore that
    # too. Overriding the derived `cargoDeps` is the hook that does take effect,
    # and `fetchCargoVendor` is exactly what `cargoHash` would have called.
    #
    # v0.23.1's Cargo.lock is 395 packages, every one a checksummed crates.io
    # entry with no git dependencies, so this is an ordinary fixed-output fetch.
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      pname = "tuicr";
      inherit version src;
      # Placeholder: `fetchCargoVendor` treats "" as "hash unknown" and the
      # build fails with the real hash to paste in here.
      hash = "sha256-1h8jDRssVA7gNfHB/9Uh1QWOsNF+aUBU698P/qLbyeY=";
    };
  };
}
