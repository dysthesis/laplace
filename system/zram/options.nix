{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkEnableOption
    ;
  inherit (lib.types)
    int
    str
    ;
in
{
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
}
