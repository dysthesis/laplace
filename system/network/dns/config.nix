{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.network.dnscrypt-proxy.enable;
in
{
  config = mkIf cfg {
    networking = {
      networkmanager.dns = "none";
      nameservers = [
        "127.0.0.1"
        "::1"
      ];
      dhcpcd.extraConfig = "nohook resolv.conf";
    };

    services.dnscrypt-proxy2 = {
      enable = true;
      settings = {
        ipv6_servers = true;
        require_dnssec = true;
        server_names = [ "odoh-cloudflare" ];
        odoh_servers = true;

        anonymized_dns = {
          routes = [
            {
              server_name = "odoh-cloudflare";
              via = [ "*" ];
            }
          ];
          skip_incompatible = false;
        };

        sources = {
          odoh-relays = {
            cache_file = "odoh-relays.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
            prefix = "";
            refresh_delay = 24;
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-relays.md"
              "https://download.dnscrypt.info/resolvers-list/v3/odoh-relays.md"
            ];
          };
          odoh-servers = {
            cache_file = "odoh-servers.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
            prefix = "";
            refresh_delay = 24;
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-servers.md"
              "https://download.dnscrypt.info/resolvers-list/v3/odoh-servers.md"
            ];
          };
          public-resolvers = {
            cache_file = "public-resolvers.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
            prefix = "";
            refresh_delay = 72;
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
              "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
            ];
          };
          relays = {
            cache_file = "relays.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
            prefix = "";
            refresh_delay = 72;
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md"
              "https://download.dnscrypt.info/resolvers-list/v3/relays.md"
            ];
          };
        };
      };
    };
  };
}
