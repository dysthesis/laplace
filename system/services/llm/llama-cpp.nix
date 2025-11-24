{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;

  models = {
    qwen2-5-coder = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf";
      sha256 = "sha256-p9gKNeiUl0sbI/hD30KftnfUQfKtGG2jFKhEm+EA/Ic=";
    };

    qwen3-coder = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
      sha256 = "sha256-+tw+X41Cv36JSnhbBQguR9ruTfJmgDiYF+IJMFbwiK0=";
    };

    gpt-oss-20b = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gpt-oss-20b-GGUF/resolve/main/gpt-oss-20b-F16.gguf";
      sha256 = "sha256-Tk+c2I1kVuTziecmLspKjVZSEeKyLs6cp6hVYWj/PGY=";
    };

    deepseek-r1-0528-qwen3-8b = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF/resolve/main/DeepSeek-R1-0528-Qwen3-8B-Q6_K.gguf";
      sha256 = "sha256-oBIFHlmuxheVHe+hZ9PjZYGW/jKohC308tHiZ4swq0A=";
    };

    gemma-3-270m-it = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gemma-3-270m-it-GGUF/resolve/main/gemma-3-270m-it-F16.gguf";
      sha256 = "sha256-FAyzlaOj3Ns95m5Exg1yZShsnUn5UcGJnsDYwfFrL+s=";
    };
  };

  model = models.deepseek-r1-0528-qwen3-8b;
  cfg = config.laplace.services.llm;
in {
  config = mkIf cfg.enable {
    # Keep all model files pinned in the system closure, so GC cannot drop them.
    system.extraDependencies = builtins.attrValues models;

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
            paths = rocmLibs;
          };
        in
          (pkgs.unstable.llama-cpp.override {
            rocmSupport = true;
          }).overrideAttrs (old: {
            env =
              (old.env or {})
              // {
                HSA_OVERRIDE_GFX_VERSION = "10.3.0";
                ROCM_PATH = "${rocmPath}";
              };
            buildInputs = old.buildInputs ++ [rocmPackages.llvm.openmp pkgs.zstd];
            dontStrip = true;
            cmakeFlags =
              (lib.filter (p: !(lib.strings.hasSuffix "hipcc" p)) old.cmakeFlags)
              ++ [
                "-DGGML_HIPBLAS=1"
                "-DGGML_CUDA_FORCE_MMQ=1"
                "-DGGML_NATIVE=1"
                "-DGGML_LTO=1"
                "-DAMDGPU_TARGETS=gfx908;gfx1030;gfx1100"
              ];
          });

        inherit model;
        inherit (cfg) port host;

        openFirewall = true;
        extraFlags = [
          "--alias"
          "gpt-oss-20b"
          "--ctx-size"
          (toString cfg.contextSize)
        ];
      };
    };
  };
}
