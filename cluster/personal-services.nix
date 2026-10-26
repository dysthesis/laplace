{
  laplace.services = {
    miniflux = {
      host = "mimir";
      settings = {
        domain = "miniflux.dysthesis.com";
        port = 8087;
        listenAddress = "0.0.0.0";
        sopsFile = ../system/secrets/mimir.yaml;
        allowPrivateNetworks = true;
        useKarakeepBrowser = true;
      };
    };
    nocodb = {
      host = "mimir";
      settings = {
        domain = "db.dysthesis.com";
        port = 8088;
        sopsFile = ../system/secrets/mimir.yaml;
      };
    };
    altero = {
      host = "mimir";
      settings = {
        domain = "lib.dysthesis.com";
        port = 8000;
        dataDir = "/var/lib/altero";
      };
    };
    silverbullet = {
      host = "mimir";
      settings = {
        domain = "silverbullet.dysthesis.com";
        port = 8101;
        listenAddress = "127.0.0.1";
      };
    };
    vikunja = {
      host = "mimir";
      settings = {
        domain = "tasks.dysthesis.com";
        port = 3456;
        listenAddress = "127.0.0.1";
      };
    };
    radicale = {
      host = "mimir";
      settings = {
        domain = "cal.dysthesis.com";
        port = 5232;
        listenAddress = "127.0.0.1";
        sopsFile = ../system/secrets/mimir.yaml;
      };
    };
    karakeep = {
      host = "mimir";
      settings = {
        domain = "read.dysthesis.com";
        port = 3000;
        listenAddress = "127.0.0.1";
        browserPort = 9222;
        searchPort = 7700;
        disableSignups = false;
      };
    };
    beszel-hub = {
      host = "mimir";
      settings = {
        domain = "status.dysthesis.com";
        port = 8090;
        listenAddress = "127.0.0.1";
        agentPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
      };
    };
    syncthing-server = {
      host = "mimir";
      settings = {
        domain = "sync.dysthesis.com";
        port = 8384;
        listenAddress = "127.0.0.1";
        dataDir = "/var/lib/syncthing";
        guiClients = ["phobos" "deimos" "phone"];
      };
    };
    livesync = {
      host = "mimir";
      settings = {
        domain = "livesync.dysthesis.com";
        port = 5984;
        listenAddress = "127.0.0.1";
        dataDir = "/var/lib/couchdb";
        sopsFile = ../system/secrets/mimir.yaml;
      };
    };
    immich = {
      host = "mneme";
      settings = {
        domain = "immich.dysthesis.com";
        port = 2283;
        listenAddress = "0.0.0.0";
        mediaLocation = "/var/lib/immich";
      };
    };
    uptime-kuma = {
      host = "horos";
      settings = {
        domain = "uptime.dysthesis.com";
        port = 3001;
        listenAddress = "127.0.0.1";
      };
    };
    ntfy = {
      host = "horos";
      settings = {
        domain = "ntfy.dysthesis.com";
        port = 2586;
        listenAddress = "127.0.0.1";
        sopsFile = ../system/secrets/horos.yaml;
      };
    };
    adguardhome = {
      host = "hermes";
      settings = {
        domain = "adguard.dysthesis.com";
        port = 80;
        listenAddress = "0.0.0.0";
        exceptionClient = "deimos";
        upstreamDNS = [
          "[/dysthesis.com/]https://dns.cloudflare.com/dns-query"
          "https://dns10.quad9.net/dns-query"
          "https://dns.adguard-dns.com/dns-query"
          "https://dns.cloudflare.com/dns-query"
        ];
      };
    };
  };
}
