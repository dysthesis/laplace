{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.hardening.malloc.enable;
in {
  config = mkIf cfg {
    environment = {
      memoryAllocator.provider = "scudo";
      variables.SCUDO_OPTIONS = "ZeroContents=1";
    };
  };
}
