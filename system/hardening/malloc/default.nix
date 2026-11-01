{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.harden;
in {
  config = mkIf (elem "malloc" cfg) {
    environment = {
      # Global hardened_malloc can crash Zen with AMD Mesa. Use Zink for Zen.
      memoryAllocator.provider = "graphene-hardened";
      variables.SCUDO_OPTIONS = "ZeroContents=1";
    };
  };
}
