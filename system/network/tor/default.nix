{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.network.tor;
in {
  options.laplace.network.tor = {
    enable = mkEnableOption "Whether or not to enable Tor";
    libera-chat-map.enable = mkEnableOption "Whether or not to enable address mapping to access Libera chat via Tor";
  };
  config = mkIf cfg.enable {
    services.tor = {
      client = {
        enable = true;
        dns.enable = true;
      };
      enable = true;
      torsocks.enable = true;
      openFirewall = true;
      # Disable relay location estimates.
      enableGeoIP = false;
      settings = {
        Sandbox = true;
        CookieAuthentication = true;
        AvoidDiskWrites = 1;
        HardwareAccel = 1;
        SafeLogging = 1;
        NumCPUs = 3;
        "MapAddress" = mkIf cfg.libera-chat-map.enable [
          "palladium.libera.chat libera75jm6of4wxpxt4aynol3xjmbtxgfyjpu34ss4d7r7q2v5zrpyd.onion"
        ];
      };
    };
    programs.proxychains = {
      enable = true;
      package = pkgs.proxychains-ng;

      proxyDNS = true;
      # Override the default SOCKS4 proxy with SOCKS5.
      proxies = lib.mkForce {
        tor = {
          enable = true;
          type = "socks5";
          host = "127.0.0.1";
          port = 9050;
        };
      };
    };
  };
}
