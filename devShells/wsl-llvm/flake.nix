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

        LLVMDir = "/workspace/llvm-project"; # FIXME: Path to llvm-project
        DXCDir = "/workspace/DirectXShaderCompiler"; # FIXME: Path to DirectXShaderCompiler
        OffloadTestDir = "/workspace/offload-test-suite"; # FIXME: Path to offload-test-suite
        GoldenImagesDir = "/workspace/offload-golden-images"; # FIXME: Path to offload-golden-images

      in
      with pkgs;
      {
        # Use magic incantation to enable native compilation with clang & lld
        # Use this magic incantation until https://github.com/NixOS/nixpkgs/issues/142901 is resolved
        devShell =
          mkShell.override
            {
              stdenv = overrideCC llvmPackages.stdenv (
                llvmPackages.stdenv.cc.override { inherit (llvmPackages) bintools; }
              );
            }
            {

              name = "llvm-wsl-env";

              buildInputs = [
                (python3.withPackages (python-pkgs: [
                  python-pkgs.pyyaml
                  python-pkgs.virtualenv
                ]))
                ninja
                sccache
                cmake
                zlib
                spirv-tools
                directx-headers
                cvise
                directx-shader-compiler
              ];

              DXC_LIBS_DIR = "${DXCDir}/build/lib";

              LLVMCMakeFlags = [

                # LLVM build options
                "-C ${LLVMDir}/clang/cmake/caches/HLSL.cmake"
                "-G Ninja"
                "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
                "-DLLVM_ENABLE_ASSERTIONS=ON"
                "-DLLVM_ENABLE_LLD=ON"
                "-DLLVM_INCLUDE_SPIRV_TOOLS_TESTS=ON"
                "-DLLVM_INCLUDE_DXIL_TESTS=ON"
                "-DLLVM_OPTIMIZED_TABLEGEN=OFF" # Not recommended to use unless making a Debug configuration

                # Sccache
                "-DCMAKE_C_COMPILER_LAUNCHER=${pkgs.sccache}/bin/sccache"
                "-DCMAKE_CXX_COMPILER_LAUNCHER=${pkgs.sccache}/bin/sccache"

                # Generate compile_commands.json for clangd
                "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"

                # Add the offload test suite to the LLVM build
                "-DLLVM_EXTERNAL_PROJECTS=OffloadTest"
                "-DLLVM_EXTERNAL_OFFLOADTEST_SOURCE_DIR=${OffloadTestDir}"
                "-DGOLDENIMAGE_DIR=${GoldenImagesDir}"
                "-DOFFLOADTEST_TEST_CLANG=ON"
                "-DDXC_DIR=${DXCDir}/build/bin"

              ];

              DXCCMakeFlags = [
                "-C ${DXCDir}/cmake/caches/PredefinedParams.cmake"
                "-G Ninja"
                "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
                "-DHLSL_DISABLE_SOURCE_GENERATION=ON"
              ];

              shellHook = ''
                alias configureLLVM="cmake -S ${LLVMDir}/llvm -B ${LLVMDir}/build \$LLVMCMakeFlags"
                alias buildLLVM="cmake --build ${LLVMDir}/build"
                alias configureDXC="cmake -S ${DXCDir} -B ${DXCDir}/build \$DXCCMakeFlags"
                alias buildDXC="cmake --build ${DXCDir}/build"
              '';

            };
      }
    );
}
