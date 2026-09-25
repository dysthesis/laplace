{
  config,
  lib,
  pkgs,
  ...
}: let
  packwizSource = builtins.path {
    path = ../../system/services/minecraft/packwiz;
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
  # Runtime Discord token and channel environment file.
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
    # Prefer local caching; keep the gateway as fallback.
    nameservers = ["127.0.0.1" "10.0.60.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };

  # Cache and serve stale records when the gateway DNS fails.
  # The gateway remains the trust boundary, so DNSSEC validation stays off.
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

  # Isolate the modpack host on VLAN60; only telemetry and deploy pinholes cross VLANs.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.60.2/24";
      Gateway = "10.0.60.1";
      DNS = "10.0.60.1";
      DHCP = "no";
    };
  };

  # spark's async-profiler samples kernel-mode frames; the default 2 rejects that
  # perf_event_open, silently degrading profiles to Java-only stacks.
  boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4; # MC main-tick thread + chunk-gen/GC workers
      memory = 12288; # MiB, 8 GiB heap plus 4 GiB overhead
      balloon = 0; # fixed allocation avoids zram and GC stalls
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
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      tailscale = {
        enable = true;
        # Avoid cold tailnet DNS links; this host only needs public names.
        denyDNS = true;
      };
      beszel.agent = {
        enable = true;
        # Mimir pulls metrics; Loki stores only the hub's public key.
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = [config.laplace.tailnet.nodes.mimir.ip];
      };
      minecraft.retirement-home = {
        enable = true;
        autoStart = true;
        restart = "on-failure";
        openFirewall = false; # tailnet-only; players reach :25565 over tailscale0
        # Keep 4 GiB outside the heap; Aikar's G1 flags reduced pregen pauses.
        extraJvmOpts = "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1";

        motd = "Oops! All skill issues!";

        # Discord bridge needs outbound port 443 only.
        discord = {
          enable = true;
          environmentFile = config.sops.secrets.discord_bot_env.path;
        };
      };

      # Serve PackWiz and Prism bootstrap files over tailnet HTTPS.
      # DNS-01 requires a Cloudflare token on this untrusted host.
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com"; # ACME account, matches the rest of the fleet
        # Policy rules expose ports 80 and 443 only on the tailnet.
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/loki.yaml; # must hold a `cloudflare_api_key` key
          # Give squaremap a root-path vhost; Headscale maps it to Loki.
          proxies."map.dysthesis.com" = "localhost:8080";
        };
        virtualHosts."mc.dysthesis.com".extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1
          }
          @notSSE not header Accept *text/event-stream*
          encode @notSSE
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
