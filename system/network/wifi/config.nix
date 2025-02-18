{
  config,
  lib,
  ...
}:
let
  cfg = config.laplace.network.wifi.enable;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg {
    networking = {
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
