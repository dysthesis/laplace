{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption mkDefault;
  inherit (lib.types) int str;
  cfg = config.laplace.zram;
in {
  options.laplace.zram = {
    enable = mkEnableOption "Whether or not to enable zram swap";
    memoryPercent = mkOption {
      type = int;
      description = "How many percent of the memory to allocate for zram swap";
      default = 50;
    };
    algorithm = mkOption {
      type = str;
      description = "Which compression algorithm to use for zram swap";
      default = "zstd";
    };
  };
  config = mkIf cfg.enable {
    zramSwap = {
      enable = true;
      inherit (cfg) memoryPercent algorithm;
    };
    # Prefer compressed swap so ballooned guests retain less physical memory.
    # swappiness 180 and page-cluster 0 suit cheap random zram access.
    boot.kernel.sysctl = {
      "vm.swappiness" = mkDefault 180;
      "vm.page-cluster" = mkDefault 0;
    };
    boot = {
      kernelParams = [
        "zswap.enabled=0"
      ];
      kernelModules = [
        "zstd"
      ];
      initrd = {
        availableKernelModules = [
          "lz4"
          "zstd"
        ];
        kernelModules = [
          "zstd"
        ];
      };
    };
  };
}
