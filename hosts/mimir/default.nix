# Application guest. Caddy fronts loopback services on tailnet-only port 443.
{
  config,
  lib,
  pkgs,
  ...
}: let
  minifluxHost = "miniflux.dysthesis.com";
  vikunjaHost = "tasks.dysthesis.com";
  alteroHost = "lib.dysthesis.com";
  beszelHost = "status.dysthesis.com";
  radicaleHost = "cal.dysthesis.com";
  karakeepHost = "read.dysthesis.com";
  syncHost = "sync.dysthesis.com";
  livesyncHost = "livesync.dysthesis.com";
in {
  sops.secrets = {
    # The Miniflux module otherwise uses the shared secret file.
    miniflux_admin.sopsFile = ../../system/secrets/mimir.yaml;
    # Beszel KEY and TOKEN environment file.
    beszel_agent_env.sopsFile = ../../system/secrets/mimir.yaml;
    radicale_htpasswd.sopsFile = ../../system/secrets/mimir.yaml;
    # Pre-hashed [admins] INI: CouchDB must not persist a stale password override.
    couchdb_admin_ini = {
      sopsFile = ../../system/secrets/mimir.yaml;
      owner = config.services.couchdb.user;
      group = config.services.couchdb.group;
      restartUnits = ["couchdb.service"];
    };
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
      memory = 5120; # MiB, ballooning ceiling (karakeep's node stack + headless chromium)
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
      nocodb = {
        enable = true;
        domain = "db.dysthesis.com";
        port = 8088;
      };
      telemetry = {
        enable = true;
        role = "apps";
        metrics = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      miniflux.enable = true;
      altero = {
        enable = true;
        domain = alteroHost;
      };
      silverbullet.enable = true;
      vikunja.enable = true;
      radicale.enable = true;
      karakeep = {
        enable = true;
        domain = karakeepHost;
      };
      beszel = {
        hub = {
          enable = true;
          appUrl = "https://${beszelHost}";
        };
        # Use loopback because agent and hub share this host.
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
        virtualHosts.${syncHost}.extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1
          }
          # Port-based tailnet ACLs cannot distinguish Mimir's HTTPS vhosts.
          # Restrict Syncthing's unauthenticated GUI to its three owner clients.
          @syncClients remote_ip ${config.laplace.tailnet.nodes.phobos.ip} ${config.laplace.tailnet.nodes.phobos.ip6} ${config.laplace.tailnet.nodes.deimos.ip} ${config.laplace.tailnet.nodes.deimos.ip6} ${config.laplace.tailnet.nodes.phone.ip} ${config.laplace.tailnet.nodes.phone.ip6}
          handle @syncClients {
            reverse_proxy 127.0.0.1:8384 {
              header_up Host {upstream_hostport}
            }
          }
          handle {
            respond 403
          }
        '';
        virtualHosts.${alteroHost}.extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1
          }
          reverse_proxy 127.0.0.1:${toString config.laplace.services.altero.port} {
            header_up X-Forwarded-For {remote_host}
          }
        '';
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/mimir.yaml;
          proxies = {
            "miniflux.dysthesis.com" = "127.0.0.1:8087";
            "silverbullet.dysthesis.com" = "localhost:8101";
            ${vikunjaHost} = "127.0.0.1:${toString config.services.vikunja.port}";
            "status.dysthesis.com" = "localhost:8090";
            ${radicaleHost} = "localhost:${toString config.laplace.services.radicale.port}";
            ${karakeepHost} = "localhost:${toString config.laplace.services.karakeep.port}";
            ${livesyncHost} = "127.0.0.1:${toString config.services.couchdb.port}";
          };
        };
      };
    };
  };

  # mnemosyne creates the persistent directory before users-groups activation;
  # ensure the Syncthing daemon can actually own and write its state directory.
  systemd.tmpfiles.rules = [
    "d ${config.services.syncthing.dataDir} 0700 syncthing syncthing - -"
  ];
  services = {
    couchdb = {
      enable = true;
      bindAddress = "127.0.0.1";
      extraConfigFiles = [config.sops.secrets.couchdb_admin_ini.path];
      extraConfig = {
        couchdb = {
          single_node = true; # Create system databases without an HTTP setup script.
          max_document_size = 50000000;
        };
        chttpd = {
          require_valid_user = true;
          enable_cors = true;
          max_http_request_size = 4294967296;
        };
        httpd = {
          enable_cors = true;
          "WWW-Authenticate" = ''Basic realm="couchdb"'';
        };
        cors = {
          credentials = true;
          origins = "app://obsidian.md,capacitor://localhost,http://localhost";
        };
      };
    };
    syncthing = {
      enable = true;
      # Caddy is the only GUI ingress; transfer ports are opened by the
      # identity-aware tailnet policy instead of the host-wide firewall.
      guiAddress = "127.0.0.1:8384";
      openDefaultPorts = false;
    };
    miniflux.config = {
      # The host firewall admits this port only for authorised tailnet peers.
      LISTEN_ADDR = lib.mkForce "0.0.0.0:8087";
      # BASE_URL controls absolute links and cookie scope; use the public origin.
      BASE_URL = lib.mkForce "https://${minifluxHost}";
      # Karakeep sits on a tailnet-only origin; Miniflux's SSRF guard otherwise
      # refuses integration POSTs to any host resolving to a non-public IP.
      INTEGRATION_ALLOW_PRIVATE_NETWORKS = "1";
      BROWSER_WEB_URL = "http://127.0.0.1:9222";
    };
    # Vikunja embeds this public origin in the frontend API configuration.
    vikunja = {
      frontendScheme = lib.mkForce "https";
      frontendHostname = lib.mkForce vikunjaHost;
    };

    silverbullet.listenAddress = lib.mkForce "127.0.0.1";
  };
  # Preserve Syncthing's state and CouchDB's databases, indexes, and node identity.
  mnemosyne.dirs = [
    config.services.syncthing.dataDir
    config.services.couchdb.databaseDir
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
