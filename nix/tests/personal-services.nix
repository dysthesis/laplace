# Evaluate the service modules without production secrets.
{
  pkgs,
  sopsModule,
  secretSource ? pkgs.writeText "personal-test-secret-source.yaml" "{}\n",
}: let
  inherit (pkgs) lib;
  catalogue = import ../../cluster/catalogue.nix {inherit lib;};
  machines.laplace = {
    hosts.fixture = {
      system = pkgs.stdenv.hostPlatform.system;
      role = "server";
      trust = "trusted";
      storage = ["persistent" "photos"];
      lan.ip = "192.0.2.10";
      caddy = true;
      dnsListenerAvailable = true;
      deployment = {};
      tailnet = {
        ip = "100.64.1.10";
        ip6 = "fd7a:115c:a1e0::10";
        tags = ["owner-device"];
      };
    };
    tailnet.peers = {
      owner = {
        ip = "100.64.1.11";
        ip6 = "fd7a:115c:a1e0::11";
        tags = ["owner-device"];
      };
      reader = {
        ip = "100.64.1.12";
        ip6 = "fd7a:115c:a1e0::12";
        tags = ["reader"];
      };
    };
    tailnet.serviceGrants = [
      {
        from.node = "owner";
        to = {
          service = "miniflux";
          endpoint = "direct";
        };
      }
    ];
    # Shared HTTPS gives access to the node, not individual virtual hosts.
    tailnet.nodeFlows = [
      {
        from.knownNodes = true;
        to.node = "fixture";
        ports = ["tcp/443"];
      }
    ];
  };
  app = domain: {
    host = "fixture";
    settings = {inherit domain;};
  };
  declarations = {
    miniflux =
      (app "rss.example.test")
      // {
        settings = {
          domain = "rss.example.test";
          sopsFile = secretSource;
          listenAddress = "0.0.0.0";
          allowPrivateNetworks = true;
        };
      };
    adguardhome =
      (app "dns.example.test")
      // {
        settings = {
          domain = "dns.example.test";
          port = 80;
          upstreamDNS = ["https://dns.quad9.net/dns-query"];
          exceptionClient = "owner";
        };
      };
    nocodb =
      (app "db.example.test")
      // {
        settings = {
          domain = "db.example.test";
          sopsFile = secretSource;
        };
      };
    silverbullet = app "notes.example.test";
    syncthing-server =
      (app "sync.example.test")
      // {
        settings = {
          domain = "sync.example.test";
          guiClients = ["owner"];
        };
      };
    livesync =
      (app "livesync.example.test")
      // {
        settings = {
          domain = "livesync.example.test";
          sopsFile = secretSource;
        };
      };
    uptime-kuma = app "uptime.example.test";
    ntfy =
      (app "ntfy.example.test")
      // {
        settings = {
          domain = "ntfy.example.test";
          sopsFile = secretSource;
        };
      };
  };
  commonModules = [
    sopsModule
    ../../modules/mnemosyne
    ../../system/docker
    ../../system/services/caddy
    ../../system/services/adguardhome
    ../../system/services/miniflux
    ../../system/services/nocodb
    ../../system/services/silverbullet
    {
      system.stateVersion = "24.11";
      mnemosyne.enable = true;
      # Evaluation does not decrypt these sources.
      sops.validateSopsFiles = false;
      laplace.services.caddy = {
        enable = true;
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = secretSource;
        };
      };
    }
  ];
  fixture = services: let
    cluster =
      (import ../../cluster {
        inherit lib;
        modules = [machines {laplace.services = services;}];
      }).manifest;
    projection = {
      imports =
        lib.mapAttrsToList (
          name: instance:
            catalogue.${name}.project {
              inherit instance cluster;
              hostName = "fixture";
            }
        )
        cluster.activeServices;
    };
  in {
    inherit cluster projection;
    modules = commonModules ++ [projection];
  };
  evaluate = services: let
    f = fixture services;
    evaluated = import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = f.modules;
    };
  in
    f // {inherit (evaluated) config;};
  enabled = evaluate {inherit (declarations) miniflux silverbullet;};
  disabled = evaluate {
    inherit (declarations) silverbullet;
    miniflux = declarations.miniflux // {enable = false;};
  };
  absent = evaluate {inherit (declarations) silverbullet;};
  nocodb = evaluate {inherit (declarations) nocodb;};
  nocodbDisabled = evaluate {nocodb = declarations.nocodb // {enable = false;};};
  sync = evaluate {inherit (declarations) syncthing-server livesync;};
  liveOnly = evaluate {
    inherit (declarations) livesync;
    syncthing-server = declarations.syncthing-server // {enable = false;};
  };
  syncOnly = evaluate {
    inherit (declarations) syncthing-server;
    livesync = declarations.livesync // {enable = false;};
  };
  notifications = evaluate {inherit (declarations) uptime-kuma ntfy;};
  ntfyOnly = evaluate {
    inherit (declarations) ntfy;
    uptime-kuma = declarations.uptime-kuma // {enable = false;};
  };
  kumaOnly = evaluate {
    inherit (declarations) uptime-kuma;
    ntfy = declarations.ntfy // {enable = false;};
  };
  adguardCaddy = {
    on80 = evaluate {inherit (declarations) adguardhome;};
    on8080 = evaluate {
      adguardhome =
        declarations.adguardhome
        // {
          settings = declarations.adguardhome.settings // {port = 8080;};
        };
      miniflux =
        declarations.miniflux
        // {
          settings = declarations.miniflux.settings // {useKarakeepBrowser = false;};
        };
    };
  };
  hasUnit = name: f: builtins.hasAttr name f.config.systemd.services;
  hasRoute = domain: f: builtins.hasAttr domain f.config.services.caddy.virtualHosts;
  hasState = path: f: builtins.elem path f.config.mnemosyne.dirs;
  hasDNS = domain: f: lib.any (r: r.name == domain) f.cluster.network.dnsRecords;
  checks = {
    minifluxEnabled =
      hasUnit "miniflux" enabled
      && hasUnit "miniflux-dbsetup" enabled
      && hasUnit "postgresql" enabled
      && enabled.config.sops.secrets ? miniflux_admin
      && hasRoute "rss.example.test" enabled
      && hasDNS "rss.example.test" enabled
      && hasState "/var/lib/postgresql" enabled
      && lib.any (c: c.owner == "miniflux" && c.ports == ["tcp/8087"]) enabled.cluster.network.connections
      && enabled.config.services.miniflux.config.LISTEN_ADDR == "0.0.0.0:8087"
      && enabled.config.services.miniflux.config.INTEGRATION_ALLOW_PRIVATE_NETWORKS == "1";
    minifluxDisabled = lib.all (
      f:
        !(hasUnit "miniflux" f)
        && !(hasUnit "miniflux-dbsetup" f)
        && !(hasUnit "postgresql" f)
        && !(f.config.sops.secrets ? miniflux_admin)
        && !(hasRoute "rss.example.test" f)
        && !(hasDNS "rss.example.test" f)
        && !(hasState "/var/lib/private/miniflux" f)
        && !(hasState "/var/lib/postgresql" f)
        && lib.all (c: c.owner != "miniflux") f.cluster.network.connections
        && !(f.cluster.network.aliases ? service-miniflux-direct-v4)
        && hasUnit "silverbullet" f
        && hasRoute "notes.example.test" f
        && hasState "/var/lib/silverbullet" f
    ) [disabled absent];
    nocodbDNSOnly =
      hasDNS "db.example.test" nocodb
      && !(hasRoute "db.example.test" nocodb)
      && nocodb.cluster.endpoints.nocodb.app.scope == "loopback"
      && hasUnit "podman-nocodb" nocodb
      && hasUnit "podman-nocodb-worker" nocodb
      && nocodb.config.virtualisation.oci-containers.containers.nocodb.ports == ["127.0.0.1:8088:8080"]
      && lib.any (r: r.kind == "uid" && r.value == "999") nocodb.cluster.resources.nocodb
      && nocodb.config.sops.secrets.nocodb_jwt_secret.sopsFile == toString secretSource;
    nocodbDisabled =
      !(hasDNS "db.example.test" nocodbDisabled)
      && !(hasUnit "podman-nocodb" nocodbDisabled)
      && !(nocodbDisabled.config.sops.secrets ? nocodb_jwt_secret)
      && !(hasState "/srv/nocodb" nocodbDisabled);
    protectedSyncthingGUI =
      sync.config.services.syncthing.guiAddress
      == "127.0.0.1:8384"
      && !sync.config.services.syncthing.openDefaultPorts
      && builtins.elem "d /var/lib/syncthing 0700 syncthing syncthing - -" sync.config.systemd.tmpfiles.rules;
    livesyncIndependent =
      hasUnit "couchdb" liveOnly
      && !(hasUnit "syncthing" liveOnly)
      && hasRoute "livesync.example.test" liveOnly
      && !(hasRoute "sync.example.test" liveOnly)
      && hasState "/var/lib/couchdb" liveOnly
      && !(hasState "/var/lib/syncthing" liveOnly)
      && liveOnly.config.sops.secrets.couchdb_admin_ini.restartUnits == ["couchdb.service"]
      && liveOnly.config.services.couchdb.extraConfig.chttpd.require_valid_user
      && liveOnly.config.services.couchdb.extraConfig.cors.origins == "app://obsidian.md,capacitor://localhost,http://localhost";
    syncthingIndependent =
      hasUnit "syncthing" syncOnly
      && !(hasUnit "couchdb" syncOnly)
      && hasRoute "sync.example.test" syncOnly
      && !(hasRoute "livesync.example.test" syncOnly)
      && hasState "/var/lib/syncthing" syncOnly
      && !(hasState "/var/lib/couchdb" syncOnly)
      && !(syncOnly.config.sops.secrets ? couchdb_admin_ini);
    notificationServicesEnabled = hasUnit "uptime-kuma" notifications && hasUnit "ntfy-sh" notifications;
    ntfyIndependent =
      hasUnit "ntfy-sh" ntfyOnly
      && !(hasUnit "uptime-kuma" ntfyOnly)
      && hasRoute "ntfy.example.test" ntfyOnly
      && !(hasRoute "uptime.example.test" ntfyOnly)
      && hasState "/var/lib/private/ntfy-sh" ntfyOnly
      && !(hasState "/var/lib/private/uptime-kuma" ntfyOnly)
      && ntfyOnly.config.services.ntfy-sh.settings.auth-default-access == "deny-all"
      && ntfyOnly.config.sops.secrets ? ntfy_env;
    kumaIndependent =
      hasUnit "uptime-kuma" kumaOnly
      && !(hasUnit "ntfy-sh" kumaOnly)
      && hasRoute "uptime.example.test" kumaOnly
      && !(hasRoute "ntfy.example.test" kumaOnly)
      && hasState "/var/lib/private/uptime-kuma" kumaOnly
      && !(hasState "/var/lib/private/ntfy-sh" kumaOnly)
      && !(kumaOnly.config.sops.secrets ? ntfy_env)
      && !(kumaOnly.config.sops.secrets ? ntfy_admin_password);
  };
in {
  inherit fixture evaluate declarations commonModules adguardCaddy;
  checks = assert lib.asserts.assertMsg (lib.all (v: v) (builtins.attrValues checks))
  "personal service projection failures: ${lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: v: !v) checks))}"; checks;
}
