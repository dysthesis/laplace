{
  config,
  lib,
  self,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.network.dnscrypt-proxy.enable;
in {
  config = mkIf cfg {
    networking = {
      networkmanager.dns = "none";
      nameservers = ["127.0.0.1" "::1"];
      dhcpcd.extraConfig = "nohook resolv.conf";
    };

    systemd = let
      name = "update-dnscrypt-blocklist";
    in {
      timers.${name} = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5m";
          onUnitActiveSec = "5h";
          Unit = "${name}.service";
        };
      };

      services.${name} = let
        utils = self.packages.${pkgs.system}.generate-domains-blocklist;
      in {
        script = ''
          set -eu
          ${utils}/generate-domains-blocklist.py -a ${utils}/domains-allowlist.txt -c ${utils}/domains-blocklist.conf -o /etc/dnscrypt-proxy/blocked-names.txt
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    };

    services.dnscrypt-proxy2 = {
      enable = true;
      settings = {
        ipv6_servers = true;
        require_dnssec = true;
        server_names = ["odoh-cloudflare"];
        odoh_servers = true;

        blocked_names = {
          blocked_names_file = "/etc/dnscrypt-proxy/blocked-names.txt";
          log_file = "/var/log/blocked-names.log";
        };

        anonymized_dns = {
          routes = [
            {
              server_name = "odoh-cloudflare";
              via = ["*"];
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
