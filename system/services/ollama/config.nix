{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
in {
  config = mkIf config.laplace.services.ollama.enable {
    services = {
      llama-cpp = {
        enable = true;
        package = let
          inherit (pkgs.unstable) rocmPackages;
          rocmLibs = with rocmPackages; [
            clr
            hipblas
            rocblas
            rocsolver
            rocsparse
            rocm-device-libs
            rocm-smi
          ];
          rocmPath = pkgs.buildEnv {
            name = "rocm-path";
            paths = rocmLibs; # ++ [ rocmClang ];
          };
        in
          (pkgs.unstable.llama-cpp.override {
            rocmSupport = true;
          }).overrideAttrs (old: {
            env =
              (old.env or {})
              // {
                HSA_OVERRIDE_GFX_VERSION = "10.3.0";
                NIX_CFLAGS_COMPILE = "-march=skylake -mtune=znver3";
                ROCM_PATH = "${rocmPath}";
              };
            #nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.clang ];
            buildInputs = old.buildInputs ++ [rocmPackages.llvm.openmp pkgs.zstd];
            dontStrip = true;
            cmakeFlags =
              (lib.filter (p: !(lib.strings.hasSuffix "hipcc" p)) old.cmakeFlags)
              ++ [
                "-DGGML_HIPBLAS=1"
                "-DGGML_CUDA_FORCE_MMQ=1"
                #	"-DGGML_HIP_UMA=1"
                "-DGGML_NATIVE=1"
                "-DGGML_LTO=1"
                #	"-DGGML_CUDA_NO_PEER_COPY=1"
                #"-DGGML_CUDA_FORCE_CUBLAS=1"
                #"-DGGML_SANITIZE_UNDEFINED=1"
                #	"-DGGML_SANITIZE_ADDRESS=1"
                #"-DLLAMA_SANITIZE_UNDEFINED=1"
                #	"-DLLAMA_SANITIZE_ADDRESS=1"
                "-DAMDGPU_TARGETS=gfx908;gfx1030;gfx1100"
                #	"-DCMAKE_BUILD_TYPE=Release"
                #	"-DCMAKE_C_COMPILER=clang" "-DCMAKE_CXX_COMPILE=clang++"
              ];
          });
        model = pkgs.fetchurl {
          url = "https://huggingface.co/unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf";
          # sha256 = "sha256-z56gVy6HWTSO9/jNiZ+/7LpREJKfwapiDRi7bZHmJwA=";
          sha256 = "sha256-p9gKNeiUl0sbI/hD30KftnfUQfKtGG2jFKhEm+EA/Ic=";
        };
        openFirewall = true;
        extraFlags = ["--n-gpu-layers" "0"];
      };
    };
  };
}
