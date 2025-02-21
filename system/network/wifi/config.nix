{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.network.wifi;
  inherit (lib) mkIf;
in {
  config = mkIf cfg.enable {
    networking = {
      wireless.enable = false;
      stevenblack.enable = true;
      enableIPv6 = true;
      networkmanager = {
        enable = true;
        wifi = {
          macAddress = "random";
          powersave = true;
        };
      };
    };
    # slows down boot time
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
