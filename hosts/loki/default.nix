{
  config,
  pkgs,
  ...
}: let
  # 408 MiB modpack served read-only over the tailnet at https://mc.dysthesis.com/modpack.
  # Lives with the minecraft service module, which builds the server mods/config
  # from the same zip — one file, no client/server drift. Symlink it into a dir
  # so Caddy's `root` has a directory to serve; the blob is *referenced*, not
  # copied, so it lands on loki's disk exactly once (the symlink target is a
  # runtime dep).
  modpackZip = builtins.path {
    path = ../../system/services/minecraft/RetirementHome.zip;
    name = "RetirementHome.zip";
  };
  modpack = pkgs.runCommand "retirement-home-modpack" {} ''
    mkdir -p "$out"
    ln -s ${modpackZip} "$out/RetirementHome.zip"
  '';
in {
  # dotenv (DISCORD_BOT_TOKEN + DISCORD_CHANNEL_ID) for the Discord bridge; fed
  # to the server's EnvironmentFile and substituted into the mod's TOML at start.
  sops.secrets.discord_bot_env.sopsFile = ../../system/secrets/loki.yaml;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    # Local unbound first (caches + serves stale over the gateway's flaky DNS);
    # the gateway stays as a fallback so loki still resolves if unbound is down.
    nameservers = ["127.0.0.1" "10.0.60.1"];
  };

  # Local caching + serve-stale resolver. denyDNS (below) removed systemd-resolved
  # and its cache, exposing the VLAN60 gateway's ~5% DNS flakiness: every uncached
  # lookup hit 10.0.60.1 raw, so JDA's per-message REST POSTs to discord.com
  # intermittently failed with EAI_AGAIN and dropped MC->Discord chat lines (the
  # gateway WebSocket survived since it resolves once and stays open). unbound
  # caches answers and, via serve-expired, hands back the last good record when
  # the gateway flakes, so resolution stops failing. Pure forwarder: the gateway
  # is the trust boundary, so skip DNSSEC validation to avoid SERVFAIL if it
  # strips DNSSEC records (no worse than the prior raw-gateway posture).
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = ["127.0.0.1"];
        access-control = ["127.0.0.0/8 allow"];
        serve-expired = true;
        serve-expired-ttl = 86400;
        prefetch = true;
        cache-min-ttl = 60;
        module-config = ''"iterator"'';
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = ["10.0.60.1"];
        }
      ];
    };
  };

  # VLAN 60, loki's own isolated segment (F10): the untrusted modpack box has no
  # legitimate VLAN20 peer (game served over tailscale0, Beszel is pulled over the
  # tunnel by mimir; runtime DNS is the VLAN60 gateway via the local unbound cache
  # below, no longer AdGuard over the tunnel). LAN reach = gateway (10.0.60.1, DNS
  # + NAT egress) + the workstation->:22 deploy pinhole only; heimdall DROPs
  # loki->VLAN20/30/40/50. The tailnet half of the containment is the SSOT `game` tag.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.60.2/24";
      Gateway = "10.0.60.1";
      DNS = "10.0.60.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4; # MC main-tick thread + chunk-gen/GC workers
      memory = 10240; # MiB, ballooning ceiling (10 GiB)
      balloon = 8192; # MiB, ballooning floor (8 GiB)
      diskSize = "64G"; # world + modpack; bump before a large chunk pregen
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale = {
        enable = true;
        # Resolve via the VLAN60 gateway (10.0.60.1) directly, not tailnet
        # MagicDNS. The AdGuard-over-tunnel path to hermes idles cold; re-punching
        # the direct link (~6s) drops bursty DNS, stalling cold lookups 10-36s and
        # timing out the Discord bot and Mojang auth (AdGuard itself answers in
        # ~4ms). denyDNS sets --accept-dns=false and disables resolved, so
        # resolv.conf falls back to networking.nameservers (10.0.60.1). Trade-off:
        # loki forgoes AdGuard filtering and tailnet split-horizon names, fine for
        # a single-purpose box talking to Discord/Mojang/mod CDNs.
        denyDNS = true;
      };
      beszel.agent = {
        enable = true;
        # SSH/pull: mimir dials IN to loki, so game cannot initiate HTTPS to the
        # hub/app vhosts on mimir. KEY is the hub's public key; no token/sops.
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = [config.laplace.tailnet.nodes.mimir.ip];
      };
      minecraft.retirement-home = {
        enable = true;
        autoStart = true; # dedicated host - the server is the point
        restart = "on-failure";
        openFirewall = false; # tailnet-only; players reach :25565 over tailscale0
        # 8 GiB heap on the 12 GiB pinned guest (ballooning disabled imperatively
        # in PVE), leaving ~4 GiB for JVM non-heap + OS + region-file page cache.
        # Sized per Aikar's rule (heap <= guest RAM - ~2 GiB): an on-host Chunky
        # pregen benchmark showed zero swap and zero full-GCs at 8 GiB, so a larger
        # heap would only enlarge the young gen and lengthen pauses. (Before the
        # pin the guest sat at its 8 GiB balloon floor and this 8 GiB heap forced
        # ~950k pages/3h into zram — GC pauses faulting them back was the tell.)
        memoryGb = 8;

        # Aikar's G1 flags — won an on-host benchmark (Chunky pregen, 3x600 s):
        # young-GC pause p99 35 ms / max 38 ms vs bare-G1 baseline p99 61 / max 108,
        # GC overhead 0.60% vs 0.82%, throughput within noise. Beat the GraalVM
        # "Obydux" set (p99 45 / max 47) too. Xms=Xmx come from memoryGb above.
        extraJvmOpts = "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1";

        motd = "Oops! All skill issues!";

        # Chat bridge. The bot dials discord.com:443 outbound through the VLAN60
        # gateway NAT (egress confirmed reachable); no inbound port is opened.
        discord = {
          enable = true;
          environmentFile = config.sops.secrets.discord_bot_env.path;
        };
      };

      # Modpack download for players over the tailnet, at https://mc.dysthesis.com/modpack.
      # HTTPS (not plain HTTP) because Firefox's HTTPS-First silently upgrades the bare
      # name to :443 and hangs forever when nothing answers there. DNS-01 via Cloudflare
      # is the fleet's issuance path for these tailnet-only names (no public A record, so
      # HTTP-01/TLS-ALPN can't validate). TRADE-OFF: this puts a zone-wide Cloudflare
      # DNS-edit token on the deliberately-untrusted modpack box; if loki is popped the
      # dysthesis.com zone is exposed. Accepted for a browser-friendly download reachable
      # by the same 'game'-tag cohort (owner + MC friends). Reuses the existing
      # mc.dysthesis.com record; Minecraft on :25565 is untouched.
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com"; # ACME account, matches the rest of the fleet
        # tailnet-only. loki mkForce-drops tailscale0 from trustedInterfaces (the SSOT
        # "flip" in system/tailnet/firewall.nix), so :80/:443 are NOT open by default —
        # the tcp/80 + tcp/443 entries on the workstation->game flow and the minecraft
        # guest reach in system/tailnet/policy.nix open them (nftables + headscale ACL).
        # openFirewall would instead open them on every interface incl. the LAN.
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/loki.yaml; # must hold a `cloudflare_api_key` key
          # squaremap web map. The caddy module turns this into an HTTPS vhost
          # (DNS-01 cert, same as mc.dysthesis.com) that reverse-proxies to
          # squaremap's loopback webserver. A dedicated subdomain (not
          # mc.dysthesis.com/map) so squaremap's SPA serves from web root with no
          # subpath asset-rewriting. bifrost's Headscale extra_records resolves
          # map.dysthesis.com -> loki's tailnet IP; the minecraft `game` ACL
          # already permits tcp/443, so the friend cohort reaches it unchanged.
          proxies."map.dysthesis.com" = "localhost:8080";
        };
        virtualHosts."mc.dysthesis.com".extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1
          }
          route /modpack {
            root * ${modpack}
            rewrite * /RetirementHome.zip
            # Force a sane download name: the request path is /modpack, so without
            # this the browser saves the zip as extensionless "modpack".
            header Content-Disposition "attachment; filename=RetirementHome.zip"
            file_server
          }
        '';
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    rsync
  ];
}
