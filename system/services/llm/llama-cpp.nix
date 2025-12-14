{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;

  models = builtins.mapAttrs (_key: val: pkgs.fetchurl val) cfg.modelRegistry;
  model = models."${cfg.model}";
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
          "${cfg.model}"
          "--ctx-size"
          (toString cfg.contextSize)
        ];
      };
    };
  };
}
