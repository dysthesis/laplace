{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.network.wifi;
  inherit
    (lib)
    mkIf
    mkDefault
    ;
in {
  config = mkIf cfg.enable {
    networking = {
      wireless.enable = mkDefault false;
      stevenblack.enable = true;
      enableIPv6 = true;
      networkmanager = {
        enable = mkDefault true;
        unmanaged = [
          "docker0"
          "rndis0"
        ];
        wifi = {
          macAddress = "random";
          powersave = true;
        };
      };
    };
    programs.nm-applet.enable = config.networking.networkmanager.enable;
    # slows down boot time
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
