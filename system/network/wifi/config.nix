{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.network.wifi.enable;
  inherit (lib) mkIf;
in {
  config = mkIf cfg {
    networking = {
      iwd.enable = true;
      networkmanager = {
        enable = true;
        wifi = {
          macAddress = "random";
          backend = "iwd";
        };
      };
    };
  };
}
