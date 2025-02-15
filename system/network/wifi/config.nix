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
      networkmanager = {
        enable = true;
        wifi = {
          # FIX: This attempts to fix the error with wpa_supplicant
          # "wlp1s0: Failed to set PTK to the driver"
          # macAddress = "random";
          powersave = true;
          # backend = "iwd";
        };
      };
    };
    programs.nm-applet = {
      enable = true;
      indicator = true;
    };
  };
}
