{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.services.adguardhome.enable;
in {
  options.laplace.services.adguardhome.enable =
    mkEnableOption "Whether or not to enable AdGuard Home";

  config = mkIf cfg {
    # Persist UI-managed rewrites and accounts.
    mnemosyne.dirs = ["/var/lib/private/AdGuardHome"];

    services.adguardhome = {
      enable = true;
      # Preserve UI changes outside declared settings; declared settings still win.
      mutableSettings = true;
      # Keep the UI closed on the LAN; tailscale0 remains trusted.
      openFirewall = false;

      # Must match the port used by node-local Caddy.
      port = 80;

      settings = {
        # Caddy terminates TLS for DoH on the plain HTTP port.
        doh.insecure_enabled = true;

        # Behind node-local Caddy, only loopback should be trusted to supply XFF.
        dns.trusted_proxies = [
          "127.0.0.0/8"
          "::1/128"
        ];

        # yaml-merge replaces lists wholesale on every start. Nix owns these
        # lists; add blocklists and rules here, not in the web UI.
        filters = [
          {
            enabled = true;
            id = 1;
            name = "AdGuard DNS filter";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          }
          {
            enabled = true;
            id = 2;
            name = "AdAway Default Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          }
          {
            enabled = true;
            id = 1781695598;
            name = "Dan Pollock's List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt";
          }
          {
            enabled = true;
            id = 1781695599;
            name = "HaGeZi's Ultimate Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_49.txt";
          }
          {
            enabled = true;
            id = 1781695600;
            name = "HUN: Hufilter";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_35.txt";
          }
          {
            enabled = true;
            id = 1781695601;
            name = "Peter Lowe's Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt";
          }
          {
            enabled = true;
            id = 1781695602;
            name = "Steven Black's List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt";
          }
          {
            enabled = true;
            id = 1781695603;
            name = "Dandelion Sprout's Game Console Adblock List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_6.txt";
          }
          {
            enabled = true;
            id = 1781695604;
            name = "HaGeZi's Apple Tracker Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_67.txt";
          }
          {
            enabled = true;
            id = 1781695605;
            name = "HaGeZi's Windows/Office Tracker Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_63.txt";
          }
          {
            enabled = true;
            id = 1781695606;
            name = "CHN: AdRules DNS List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_29.txt";
          }
          {
            enabled = true;
            id = 1781695607;
            name = "CHN: anti-AD";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_21.txt";
          }
          {
            enabled = true;
            id = 1781695608;
            name = "HaGeZi's Threat Intelligence Feeds";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_44.txt";
          }
          {
            enabled = true;
            id = 1781695609;
            name = "IDN: ABPindo";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_22.txt";
          }
          {
            enabled = true;
            id = 1781695610;
            name = "HaGeZi's The World's Most Abused TLDs";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_56.txt";
          }
          {
            enabled = true;
            id = 1781695611;
            name = "IRN: PersianBlocker list";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_19.txt";
          }
          {
            enabled = true;
            id = 1781695612;
            name = "VNM: ABPVN List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_16.txt";
          }
          {
            enabled = true;
            id = 1781695613;
            name = "ISR: EasyList Hebrew";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_43.txt";
          }
          {
            enabled = true;
            id = 1781695614;
            name = "TUR: Turkish Ad Hosts";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_40.txt";
          }
          {
            enabled = true;
            id = 1781695615;
            name = "KOR: List-KR DNS";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_25.txt";
          }
          {
            enabled = true;
            id = 1781695616;
            name = "TUR: turk-adlist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_26.txt";
          }
          {
            enabled = true;
            id = 1781695617;
            name = "KOR: YousList";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_15.txt";
          }
          {
            enabled = true;
            id = 1781695618;
            name = "SWE: Frellwit's Swedish Hosts File";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_17.txt";
          }
          {
            enabled = true;
            id = 1781695619;
            name = "LIT: EasyList Lithuania";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_36.txt";
          }
          {
            enabled = true;
            id = 1781695620;
            name = "POL: Polish filters for Pi-hole";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_14.txt";
          }
          {
            enabled = true;
            id = 1781695621;
            name = "MKD: Macedonian Pi-hole Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_20.txt";
          }
          {
            enabled = true;
            id = 1781695622;
            name = "POL: CERT Polska List of malicious domains";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_41.txt";
          }
          {
            enabled = true;
            id = 1781695623;
            name = "NOR: Dandelion Sprouts nordiske filtre";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_13.txt";
          }
          {
            enabled = true;
            id = 1781923944;
            name = "OISD Blocklist Big";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_27.txt";
          }
          {
            enabled = true;
            id = 1781923945;
            name = "HaGeZi's Gambling Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_47.txt";
          }
          {
            enabled = true;
            id = 1781923946;
            name = "Stalkerware Indicators List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_31.txt";
          }
          {
            enabled = true;
            id = 1781923947;
            name = "HaGeZi's OPPO & Realme Tracker Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_66.txt";
          }
          {
            enabled = true;
            id = 1781923948;
            name = "NoCoin Filter List";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt";
          }
        ];
        whitelist_filters = [];
        user_rules = [
          "@@||api.ipify.org^$important"
          "@@||ipify.org^$important"
          "@@||clickclickclick.click^$client='100.64.0.4'"
          "@@||clickclickclick.click^$important"
          "@@||raw.utscsec.win^$important"
          "@@||www.iroh.computer^$important"
          "@@||arshad.fyi^$important"
          "@@||paisa.fyi^$important"
          "@@||mccd.space^$important"
          "@@||notes.hella.cheap^$important"
          ""
        ];

        # Route dysthesis.com directly to Cloudflare to avoid stale negative replies
        # winning parallel upstream races. Nix owns this list; UI edits are temporary.
        dns.upstream_dns = [
          "[/dysthesis.com/]https://dns.cloudflare.com/dns-query"
          "https://dns10.quad9.net/dns-query"
          "https://dns.adguard-dns.com/dns-query"
          "https://dns.cloudflare.com/dns-query"
        ];
      };
    };

    # Open DNS to LAN and tailnet; keep the UI tailnet-only.
    networking.firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
