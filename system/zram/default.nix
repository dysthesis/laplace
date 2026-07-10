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
    # Bias the VM toward compressed in-RAM swap so cold anonymous pages move
    # into zram (a few-x smaller) instead of sitting as full-size RSS. On a
    # ballooned guest this shrinks the resident footprint the host must back,
    # letting the balloon reclaim more before real pressure. swappiness=180 is
    # the zram-era recommended value (range extends to 200 on modern kernels);
    # page-cluster=0 reads one page at a time, matching zram's cheap random
    # decompression. mkDefault so a host can override.
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
