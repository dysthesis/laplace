{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.laplace.network.wifi;
  desktop = config.laplace.desktop;
  integrated = desktop != null && desktop.shell != null;
  inherit
    (lib)
    mkEnableOption
    mkIf
    mkDefault
    ;
in {
  options.laplace.network.wifi.enable = mkEnableOption "Whether or not to enable Wi-Fi support.";
  config = mkIf cfg.enable {
    networking = {
      wireless.enable = mkDefault false;
      stevenblack.enable = true;
      enableIPv6 = true;
      networkmanager = {
        enable = mkDefault true;
        plugins = with pkgs; [
          networkmanager-openvpn
        ];
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
    # The integrated shell has network status and controls.
    programs.nm-applet.enable =
      config.networking.networkmanager.enable
      && !integrated;
    # The wait service delays boot.
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
