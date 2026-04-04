{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      flake-compat,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs)
          mkShell
          overrideCC
          llvmPackages
          callPackage
          symlinkJoin
          ;

        systemParts = nixpkgs.lib.splitString "-" system;
        arch = nixpkgs.lib.head systemParts;

        llvmStdenv = overrideCC llvmPackages.stdenv (llvmPackages.stdenv.cc.override { inherit (llvmPackages) bintools; });

        LLVMDir = "~/workspace/llvm-project"; # FIXME: Path to llvm-project
        OffloadTestDir = "~/workspace/offload-test-suite"; # FIXME: Path to offload-test-suite
        GoldenImagesDir = "~/workspace/offload-golden-images"; # FIXME: Path to offload-golden-images
      in
      rec {
        packages = {
          winsysroot = callPackage ./winsysroot.nix { };
          llvm-combined = symlinkJoin {
            name = "llvm-combined";
            paths = with llvmPackages; [
              # It appears that paths specified first take higher priority here
              clang
              bintools
              clang-unwrapped
              bintools-unwrapped
            ];
          };
        };

        devShells.default =
          let
            inherit (packages) llvm-combined winsysroot;
          in
          mkShell.override { stdenv = llvmStdenv; } {

            name = "WinMsvc-llvm";

            nativeBuildInputs =
              builtins.attrValues {
                inherit (pkgs)
                  ninja
                  sccache
                  cmake
                  zlib
                  spirv-tools
                  directx-headers
                  directx-shader-compiler # just for local testing, not building
                  ;
              }
              ++ [
                (pkgs.python3.withPackages (python-pkgs: [ python-pkgs.pyyaml ]))
                winsysroot
                llvm-combined
              ];

            # GoldenImages = pkgs.fetchFromGitHub {
            #   repo = "offload-golden-images";
            #   owner = "llvm";
            #   rev = "31f7b42195fddeda9150fbeb5233c0edce12b430";
            #   hash = "";
            # };

            # Environment variables to let the offload-test-suite find D3D12 headers and libraries
            WIN10_SDK_PATH = "${winsysroot}/Windows Kits/10";
            WIN10_SDK_VERSION = nixpkgs.lib.removeSuffix ".0" winsysroot.WINSDK_VER;

            LLVMCMakeFlags = [
              # LLVM build options
              "-G Ninja"
              "-DCMAKE_TOOLCHAIN_FILE=${LLVMDir}/llvm/cmake/platforms/WinMsvc.cmake"
              "-DHOST_ARCH=${arch}"
              "-DLLVM_NATIVE_TOOLCHAIN=${llvm-combined}"
              "-DLLVM_WINSYSROOT=${winsysroot}"
              "-DMSVC_VER=${winsysroot.MSVC_VER}"
              "-DWINSDK_VER=${winsysroot.WINSDK_VER}"

              "-C ${LLVMDir}/clang/cmake/caches/HLSL.cmake"
              "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
              "-DLLVM_ENABLE_ASSERTIONS=ON"
              "-DLLVM_ENABLE_LLD=ON"
              "-DLLVM_INCLUDE_SPIRV_TOOLS_TESTS=ON"
              "-DLLVM_INCLUDE_DXIL_TESTS=ON"
              "-DLLVM_OPTIMIZED_TABLEGEN=OFF" # Not recommended to use unless making a Debug configuration

              # Generate compile_commands.json for clangd
              "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"

              # Add the offload test suite to the LLVM build
              "-DLLVM_EXTERNAL_PROJECTS=OffloadTest"
              "-DLLVM_EXTERNAL_OFFLOADTEST_SOURCE_DIR=${OffloadTestDir}"
              "-DGOLDENIMAGE_DIR=${GoldenImagesDir}"
              "-DOFFLOADTEST_TEST_CLANG=ON"
              # "-DDXC_DIR=${pkgs.directx-shader-compiler}/bin" # We want use DXC for windows, which we can get elsewhere.
            ];

            shellHook = ''
              alias configureLLVM="cmake -S ${LLVMDir}/llvm -B ${LLVMDir}/build \$LLVMCMakeFlags"
              alias buildLLVM="cmake --build ${LLVMDir}/build"
            '';

          };
      }
    );
}
