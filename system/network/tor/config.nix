{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.network.tor;
in {
  config = mkIf cfg.enable {
    services.tor = {
      client = {
        enable = true;
        dns.enable = true;
      };
      enable = true;
      torsocks.enable = true;
      openFirewall = true;
      # Disable GeoIP to prevent the Tor client from estimating the locations of Tor nodes it connects to
      enableGeoIP = false;
      settings = {
        Sandbox = true;
        # Performance and security settings
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
      # NOTE: We use mkForce here because by default, a tor proxy is already
      # configured, but it uses the outdated "socks4" instead of "socks5"
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
