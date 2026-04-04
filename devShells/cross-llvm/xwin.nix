{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  name = "xwin";
  version = "0.6.6";

  src = fetchFromGitHub {
    owner = "Jake-Shadle";
    repo = "xwin";
    rev = "${finalAttrs.version}";
    hash = "sha256-bow/TJ6aIXoNZDqCTlQYAMxEUiolby1axsKiLMk/jiA=";
  };

  # Tests require network access. Skipping.
  doCheck = false;

  useFetchCargoVendor = true;
  cargoHash = "sha256-S/3EjlG0Dr/KKAYSFaX/aFh/CIc19Bv+rKYzKPWC+MI=";

  meta = with lib; {
    description = "A utility for downloading and packaging the Microsoft CRT & Windows SDK headers and libraries needed for compiling and linking programs targeting Windows.";
    mainProgram = "xwin";
    homepage = "https://github.com/Jake-Shadle/xwin";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ ];
  };
})
