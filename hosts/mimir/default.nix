# Miniflux + SilverBullet + TaskChampion + Radicale host, running as a Proxmox guest. Generic VM concerns
# (disk, impermanence, bootloader, virtio, qemuGuest, the archon admin user, the
# VMA artifact) live in the `proxmox` profile; this module only declares the apps.
#
# TLS terminates on the node-local Caddy. Apps bind loopback; only Caddy reaches
# their raw ports, and :443 is tailnet-only via laplace.services.tailscale.
{
  config,
  lib,
  pkgs,
  ...
}: let
  minifluxHost = "miniflux.dysthesis.com";
  beszelHost = "status.dysthesis.com";
  radicaleHost = "cal.dysthesis.com";
  wallabagHost = "wallabag.dysthesis.com";
  histerHost = "search.dysthesis.com";
in {
  sops.secrets = {
    # miniflux_admin lives in mimir's own sops file (moved out of the shared
    # secrets.yaml); the miniflux module declares the secret against the default
    # file, so repoint it.
    miniflux_admin.sopsFile = ../../system/secrets/mimir.yaml;
    # beszel agent's KEY + mimir's per-system TOKEN, consumed as the agent's
    # EnvironmentFile below.
    beszel_agent_env.sopsFile = ../../system/secrets/mimir.yaml;
    radicale_htpasswd.sopsFile = ../../system/secrets/mimir.yaml;
    # wallabag's Symfony secret; add `wallabag_secret` to mimir.yaml (openssl rand -hex 32).
    wallabag_secret.sopsFile = ../../system/secrets/mimir.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/mimir.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/mimir.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.83/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 2;
      memory = 5120; # MiB, ballooning ceiling (bleve indexing + ~500 MB embedder)
      balloon = 1280; # MiB, ballooning floor (Postgres + app processes)
      diskSize = "32G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale.enable = true;
      telemetry = {
        enable = true;
        role = "apps";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/mimir/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/mimir/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      miniflux.enable = true;
      silverbullet.enable = true;
      taskchampion.enable = true;
      radicale.enable = true;
      wallabag = {
        enable = true;
        domain = wallabagHost;
        adminUser = "demiurge";
        adminEmail = "demiurge@localhost";
      };
      hister = {
        enable = true;
        domain = histerHost;
        embedding.enable = true;
        # Reference doc corpora pulled + imported weekly. Trim to taste; slugs
        # are the full set from https://hister.org/datasets bar powershell.
        datasets = [
          "go-stdlib"
          "rust-docs"
          "python-docs"
          "nodejs-api"
          "mdn-css"
          "mdn-html"
          "mdn-js"
        ];
      };
      beszel = {
        hub = {
          enable = true;
          appUrl = "https://${beszelHost}";
        };
        # Colocated with the hub: dial it direct on loopback, skipping Caddy/TLS
        # and the tailnet round-trip. KEY + TOKEN come from the sops env file.
        agent = {
          enable = true;
          hubUrl = "http://localhost:8090";
          environmentFile = config.sops.secrets.beszel_agent_env.path;
        };
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # tailnet-only; :443 reached over tailscale0
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/mimir.yaml;
          proxies = {
            "miniflux.dysthesis.com" = "localhost:8087";
            "silverbullet.dysthesis.com" = "localhost:8101";
            "tasks.dysthesis.com" = "localhost:${toString config.laplace.services.taskchampion.port}";
            "status.dysthesis.com" = "localhost:8090";
            ${radicaleHost} = "localhost:${toString config.laplace.services.radicale.port}";
            ${wallabagHost} = "localhost:${toString config.laplace.services.wallabag.port}";
            ${histerHost} = "localhost:${toString config.laplace.services.hister.port}";
          };
        };
      };
    };
  };

  services = {
    miniflux.config = {
      LISTEN_ADDR = lib.mkForce "127.0.0.1:8087";
      # Miniflux bakes BASE_URL into absolute links + cookie scope, so it must
      # match the public origin Caddy serves, not the module's bare-localhost
      # default.
      BASE_URL = lib.mkForce "https://${minifluxHost}";
    };
    silverbullet.listenAddress = lib.mkForce "127.0.0.1";
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
