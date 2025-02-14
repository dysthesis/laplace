{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.zram;
in
{
  config = mkIf cfg.enable {
    zramSwap = {
      enable = true;
      inherit (cfg) memoryPercent;
    };
    boot = {
      kernelParams = [
        "zswap.enabled=0"
      ];
      kernelModules = [
        "zstd"
        "z3fold"
      ];
      initrd = {
        availableKernelModules = [
          "lz4"
          "zstd"
          "z3fold"
        ];
        kernelModules = [
          "z3fold"
          "zstd"
        ];
      };
    };
  };
}
