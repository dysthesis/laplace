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
      # Global hardened_malloc can crash Zen's AMD Mesa path; force Zink.
      memoryAllocator.provider = "graphene-hardened";
      variables.SCUDO_OPTIONS = "ZeroContents=1";
    };
  };
}
