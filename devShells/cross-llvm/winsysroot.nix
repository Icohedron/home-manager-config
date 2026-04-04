{
  stdenvNoCC,
  gcab,
  msitools,
  cacert,
  python3,
  git,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  name = "winsysroot";
  version = "17.14.8";
  manifest = ./${finalAttrs.version}.manifest;
  WINSDK_VER = "10.0.26100.0";
  MSVC_VER = "14.44.35207";

  src = fetchFromGitHub {
    repo = "msvc-wine";
    owner = "mstorsjo";
    rev = "cb78cc0bc91a9e3da69989b76b99d6f44a7d1a69";
    hash = "sha256-oeaM9Djlnyv3lBTPmKrPefvqaL0tnY1an6/CXpq0z1c=";
  };

  nativeBuildInputs = [
    gcab
    msitools
    cacert
    python3
    git
  ];

  buildPhase = ''
    runHook preBuild
    python vsdownload.py --accept-license --manifest ${finalAttrs.manifest} --dest dest

    # Function to check for specific version directories
    # $1: base_path (e.g., "./VC/Tools/MSVC/")
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
          "Mismatch in the $component_name version! We have version '$actual_version'" \
          "and expected the $component_name version to be '$expected_version'"
        exit 3
      fi
    }

    check_version "dest/VC/Tools/MSVC/" "MSVC" "$MSVC_VER"
    check_version "dest/Windows Kits/10/Include/" "Windows SDK" "$WINSDK_VER"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/VC/Tools
    mkdir -p "$out/Windows Kits/10"
    cp -r dest/VC/Tools/MSVC $out/VC/Tools/
    cp -r "dest/Windows Kits/10/Include" "$out/Windows Kits/10/"
    cp -r "dest/Windows Kits/10/Lib" "$out/Windows Kits/10/"
    runHook postInstall
  '';

  # Make this a fixed-output derivation to allow network access but require a known output hash
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "sha256-gDWcwP7v3sKw+CDMm2kaeD89T+SEr0gtQyhe0FYvCUc=";
})
