{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (lib) mkIf getExe;
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
        utils = inputs.babel.packages.${pkgs.system}.generate-domains-blocklist;
        blocklist = pkgs.writeText "blocklist.txt" ''
          https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt
          https://easylist-downloads.adblockplus.org/easylist_noelemhide.txt
          https://easylist-downloads.adblockplus.org/easylistchina.txt
          https://easylist-downloads.adblockplus.org/advblock.txt
          https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml
          https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt
          https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt
          https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
          https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
          https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADomains.txt
          https://paulgb.github.io/BarbBlock/blacklists/domain-list.txt
          https://someonewhocares.org/hosts/hosts
          https://raw.githubusercontent.com/notracking/hosts-blocklists/master/dnscrypt-proxy/dnscrypt-proxy.blacklist.txt
          https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains
          https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
          https://hostfiles.frogeye.fr/firstparty-trackers.txt
          https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
          https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt
          https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt
          https://raw.githubusercontent.com/anudeepND/blacklist/master/CoinMiner.txt
          https://dblw.oisd.nl/
          https://dblw.oisd.nl/extra/
          https://raw.githubusercontent.com/jdlingyu/ad-wars/master/sha_ad_hosts
        '';
        timeRestricted = pkgs.writeText "time-restricted" '''';
      in {
        script = ''
          set -eu
          ${getExe pkgs.python3} ${utils}/generate-domains-blocklist.py -a ${utils}/domains-allowlist.txt -c ${blocklist} -r ${timeRestricted} -o /etc/dnscrypt-proxy/blocked-names.txt

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

        blocked_names.blocked_names_file = "/etc/dnscrypt-proxy/blocked-names.txt";

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
