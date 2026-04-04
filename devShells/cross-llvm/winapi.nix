{
  stdenv,
  xwin,
  manifest,
  gcab,
  msitools,
  cacert,
}:
stdenv.mkDerivation (finalAttrs: {
  name = "winsysroot";
  version = "0.0.1";

  MSVC_VER = "14.44.17.14";
  WINSDK_VER = "10.0.26100";

  src = ./.;

  buildInputs = [ xwin ];

  buildPhase = ''
    # xwin downloads the headers and libraries to ./.xwin-cache by default
    xwin --accept-license --manifest ${manifest} splat --preserve-ms-arch-notation --disable-symlinks --use-winsysroot-style

    # Function to check for specific version directories
    # $1: base_path (e.g., ".xwin-cache/VC/Tools/MSVC/")
    # $2: component_name (e.g., "MSVC")
    # $3: expected_version (e.g., "$MSVC_VER")
    check_version() {
      local base_path="$1"
      local component_name="$2"
      local expected_version="$3"
      local actual_version=""

      local expected_full_path="$base_path$expected_version"

      # Check if the expected directory exists
      if [ ! -d "$expected_full_path" ]; then
        # If the expected directory doesn't exist, try to find the actual version present
        # This command lists directories in base_path, takes the first one, and extracts its name.
        # 2>/dev/null suppresses errors if no directories are found.
        actual_version=$(ls -d "$base_path"/*/ 2>/dev/null | head -n 1 | xargs -n 1 basename)
        echo >&2 \
          "\nMismatch in the $component_name version! We have version '$actual_version'" \
          "and expected the $component_name version to be '$expected_version'"
        exit 3
      fi
    }

    check_version "./.xwin-cache/splat/VC/Tools/MSVC/" "MSVC" "$MSVC_VER"
    check_version "./.xwin-cache/splat/Windows Kits/10/include/" "Windows SDK" "$WINSDK_VER"
  '';

  installPhase = ''
    mkdir $out
    cp -r "./.xwin-cache/splat/VC" $out
    cp -r "./.xwin-cache/splat/Windows Kits" $out

    # msvcrtd.lib is missing from the splat
    mv "./.xwin-cache/unpack/Microsoft.VC.$MSVC_VER.CRT.x64.Store.base.vsix/lib/x64/msvcrtd.lib" "$out/VC/Tools/MSVC/$MSVC_VER/lib/x64/msvcrtd.lib"

    # The casing for Windows SDK inclue and lib folders is not correct, so we fix it here https://github.com/Jake-Shadle/xwin/issues/146
    mv "$out/Windows Kits/10/include" "$out/Windows Kits/10/Include"
    mv "$out/Windows Kits/10/lib" "$out/Windows Kits/10/Lib"
  '';

  # Make this a fixed-output derivation to allow network access but requires output hash beforehand
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "sha256-F60Q4VO7YuP2ABLT1m+MYpPY1nDQgSjhOTGRModRuX4=";
})
