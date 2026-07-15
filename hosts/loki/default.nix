{
  config,
  lib,
  pkgs,
  ...
}: let
  packwizSource = builtins.path {
    path = ../../system/services/minecraft/retirement-home-packwiz;
    name = "retirement-home-packwiz";
  };
  packwizUrl = "https://mc.dysthesis.com/packwiz/pack.toml";
  packwizBootstrapJar = pkgs.fetchurl {
    url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar";
    hash = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
  };
  packwizIcon = ../../system/services/minecraft/retirement-home.png;
  packwizBootstrap = pkgs.runCommand "retirement-home-packwiz-bootstrap" {nativeBuildInputs = [pkgs.zip];} ''
    mkdir -p work/minecraft "$out"
    cp ${packwizBootstrapJar} work/minecraft/packwiz-installer-bootstrap.jar
    cp ${packwizIcon} work/retirement-home.png
    # Pre-seed Minecraft's multiplayer server list (NBT): Retirement Home -> mc.dysthesis.com.
    printf '\x0a\x00\x00\x09\x00\x07servers\x0a\x00\x00\x00\x01\x08\x00\x04name\x00\x0fRetirement Home\x08\x00\x02ip\x00\x10mc.dysthesis.com\x00\x00' > work/minecraft/servers.dat
    cat > work/instance.cfg <<'EOF'
    [General]
    ConfigVersion=1.3
    ExportAuthor=dysthesis
    ExportName=Retirement Home
    ExportSummary=Custom modpack built on Fabulously Optimized, built for a private server.
    ExportVersion=1.0.0
    InstanceType=OneSix
    ManagedPack=false
    ManagedPackID=
    ManagedPackName=
    ManagedPackType=
    ManagedPackURL=
    ManagedPackVersionID=
    ManagedPackVersionName=
    MaxMemAlloc=5120
    MinMemAlloc=2048
    OverrideCommands=true
    OverrideMemory=true
    PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar -g ${packwizUrl}
    iconKey=retirement-home
    name=Retirement Home

    [UI]
    EOF
    cat > work/mmc-pack.json <<'EOF'
    {
      "components": [
        { "uid": "net.minecraft", "version": "1.20.1" },
        { "uid": "net.fabricmc.fabric-loader", "version": "0.18.4" }
      ],
      "formatVersion": 1
    }
    EOF
    (cd work && zip -qr "$out/RetirementHome-bootstrap.zip" instance.cfg mmc-pack.json minecraft/packwiz-installer-bootstrap.jar minecraft/servers.dat retirement-home.png)
  '';
in {
  # dotenv (DISCORD_BOT_TOKEN + DISCORD_CHANNEL_ID) for the Discord bridge; fed
  # to the server's EnvironmentFile and substituted into the mod's TOML at start.
  sops.secrets = {
    discord_bot_env.sopsFile = ../../system/secrets/loki.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/loki.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/loki.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    # Local unbound first (caches + serves stale over the gateway's flaky DNS);
    # the gateway stays as a fallback so loki still resolves if unbound is down.
    nameservers = ["127.0.0.1" "10.0.60.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };

  # Local caching + serve-stale resolver. denyDNS (below) removed resolved's
  # cache, so every uncached lookup hit the gateway's ~5% flaky DNS raw: JDA's
  # per-message REST POSTs got EAI_AGAIN and MC->Discord chat lines dropped
  # (the gateway WebSocket survived — it resolves once). unbound caches and
  # serves expired records when the gateway flakes. Pure forwarder, no DNSSEC
  # validation: the gateway is the trust boundary and may strip DNSSEC records
  # (no worse than the prior raw-gateway posture).
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

  # VLAN 60, loki's own isolated segment
  # the untrusted modpack box reaches only Argus on VLAN20 over the narrow TCP
  # 8443/8444 telemetry exception (game over tailscale0, Beszel pulled by mimir,
  # DNS via local unbound -> VLAN60 gateway). Other LAN reach = gateway (DNS +
  # NAT egress) + the workstation -> :22 deploy pinhole; heimdall DROPs all other
  # loki -> VLAN20/30/40/50 flows. The tailnet half of the containment is the
  # SSOT `game` tag.
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
      memory = 12288; # MiB, 8 GiB heap plus 4 GiB non-heap/OS headroom
      balloon = 0; # reclaim at the old 8 GiB floor caused zram/GC stalls
      diskSize = "64G"; # world + modpack; bump before a large chunk pregen
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      telemetry = {
        enable = true;
        role = "game";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/loki/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/loki/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      tailscale = {
        enable = true;
        # Resolve via the VLAN60 gateway, not MagicDNS: the AdGuard-over-tunnel
        # path idles cold, and re-punching the direct link (~6s) stalled cold
        # lookups 10-36s, timing out the Discord bot and Mojang auth. denyDNS
        # sets --accept-dns=false and disables resolved, so resolv.conf falls
        # back to networking.nameservers. Trade-off: no AdGuard filtering or
        # split-horizon names — fine for a box talking only to
        # Discord/Mojang/mod CDNs.
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
        # 8 GiB heap on the 12 GiB pinned guest leaves ~4 GiB for JVM non-heap +
        # OS + page cache.
        # Chunky-pregen bench: zero swap, zero full GCs at 8 GiB. Before the pin
        # the guest sat at its 8 GiB balloon floor and this heap forced ~950k
        # pages/3h into zram — GC pauses faulting them back was the tell.
        memoryGb = 8;

        # Aikar's G1 flags — won the on-host bench (Chunky pregen, 3x600 s):
        # young-GC p99 35 ms / max 38 vs bare G1's 61/108, GC overhead 0.60% vs
        # 0.82%; also beat the GraalVM "Obydux" set (45/47). Xms=Xmx from memoryGb.
        extraJvmOpts = "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1";

        motd = "Oops! All skill issues!";

        # Chat bridge; bot dials discord.com:443 outbound via VLAN60 NAT, no
        # inbound port.
        discord = {
          enable = true;
          environmentFile = config.sops.secrets.discord_bot_env.path;
        };
      };

      # Modpack downloads over the tailnet: /packwiz/pack.toml is the live
      # source, /bootstrap a Prism instance ZIP that self-updates from it.
      # HTTPS because Firefox HTTPS-First hangs forever on a bare name with
      # nothing on :443; DNS-01 via Cloudflare since the tailnet-only name has
      # no public A record for HTTP-01. TRADE-OFF: puts a zone-wide Cloudflare
      # DNS-edit token on the deliberately-untrusted box — accepted for a
      # browser-friendly download for the `game` cohort.
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com"; # ACME account, matches the rest of the fleet
        # tailnet-only: loki mkForce-drops tailscale0 from trustedInterfaces
        # (the SSOT flip in system/tailnet/firewall.nix); tcp/80+443 open only
        # via the flows in system/tailnet/policy.nix. openFirewall would open
        # them on the LAN too.
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/loki.yaml; # must hold a `cloudflare_api_key` key
          # squaremap web map: HTTPS vhost (DNS-01, as above) proxying its
          # loopback webserver. Own subdomain rather than mc.dysthesis.com/map
          # so the SPA serves from web root without subpath asset rewrites.
          # Headscale extra_records resolves it to loki's tailnet IP; the
          # `game` ACL already permits tcp/443.
          proxies."map.dysthesis.com" = "localhost:8080";
        };
        virtualHosts."mc.dysthesis.com".extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1
          }
          route /packwiz/* {
            root * ${packwizSource}
            uri strip_prefix /packwiz
            file_server
          }
          route /bootstrap/RetirementHome-bootstrap.zip {
            root * ${packwizBootstrap}
            rewrite * /RetirementHome-bootstrap.zip
            header Content-Disposition "attachment; filename=RetirementHome-bootstrap.zip"
            file_server
          }
        '';
      };
    };
  };

  services.vmagent.prometheusConfig.scrape_configs = lib.mkAfter [
    {
      job_name = "minecraft";
      scrape_interval = "15s";
      scrape_timeout = "5s";
      sample_limit = 5000;
      label_limit = 40;
      static_configs = [{targets = ["127.0.0.1:25585"];}];
    }
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
    rsync
  ];
}
