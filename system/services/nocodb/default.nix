{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.nocodb;
  dataDir = "/srv/nocodb";
  network = "nocodb";

  image = "docker.io/nocodb/nocodb:2026.09.0";

  commonEnvironment = {
    NC_SITE_URL = "https://${cfg.domain}";
    NC_REDIS_URL = "redis://redis:6379";
    NC_DISABLE_MUX = "true";
    NC_ATTACHMENT_ACCESS_CONTROL_ENABLED = "true";

    NC_DISABLE_TELE = "true";
    NC_DISABLE_ERR_REPORTS = "true";
    NC_DISABLE_SUPPORT_CHAT = "true";
  };

  commonOptions = [
    "--network=${network}"
    "--pull=missing"
    "--cap-drop=ALL"
    "--security-opt=no-new-privileges"
  ];
in {
  options.laplace.services.nocodb =
    {enable = lib.mkEnableOption "NocoDB";}
    // import ./settings.nix {inherit lib;};

  config = lib.mkIf cfg.enable {
    laplace.docker.enable = true;

    mnemosyne.dirs = [
      dataDir
      "/var/backups/nocodb"
    ];

    sops = {
      secrets = {
        nocodb_postgres_password.sopsFile = cfg.sopsFile;
        nocodb_jwt_secret.sopsFile = cfg.sopsFile;
        nocodb_connection_key.sopsFile = cfg.sopsFile;
      };

      templates = {
        "nocodb.env".content = ''
          NC_DB=pg://db:5432?u=nocodb&p=${config.sops.placeholder.nocodb_postgres_password}&d=nocodb
          NC_AUTH_JWT_SECRET=${config.sops.placeholder.nocodb_jwt_secret}
          NC_CONNECTION_ENCRYPT_KEY=${config.sops.placeholder.nocodb_connection_key}
        '';

        "nocodb-postgres.env".content = ''
          POSTGRES_PASSWORD=${config.sops.placeholder.nocodb_postgres_password}
        '';
      };
    };

    virtualisation.oci-containers.containers = {
      nocodb = {
        inherit image;
        autoStart = true;
        environment = commonEnvironment;
        environmentFiles = [
          config.sops.templates."nocodb.env".path
        ];
        ports = [
          "127.0.0.1:${toString cfg.port}:8080"
        ];
        volumes = [
          "${dataDir}/data:/usr/app/data"
        ];
        extraOptions = commonOptions;
      };

      nocodb-worker = {
        inherit image;
        autoStart = true;
        environment =
          commonEnvironment
          // {
            NC_WORKER_CONTAINER = "true";
          };
        environmentFiles = [
          config.sops.templates."nocodb.env".path
        ];
        volumes = [
          "${dataDir}/data:/usr/app/data"
        ];
        extraOptions = commonOptions;
      };

      nocodb-postgres = {
        image = "docker.io/library/postgres:17.10";
        autoStart = true;
        environment = {
          POSTGRES_USER = "nocodb";
          POSTGRES_DB = "nocodb";
          POSTGRES_INITDB_ARGS = "--data-checksums";
        };
        environmentFiles = [
          config.sops.templates."nocodb-postgres.env".path
        ];
        volumes = [
          "${dataDir}/postgres:/var/lib/postgresql/data"
        ];
        extraOptions = [
          "--network=${network}"
          "--network-alias=db"
          "--pull=missing"
        ];
      };

      nocodb-redis = {
        image = "docker.io/library/redis:7.4.11";
        autoStart = true;
        cmd = ["redis-server" "--appendonly" "yes"];
        volumes = [
          "${dataDir}/redis:/data"
        ];
        extraOptions = [
          "--network=${network}"
          "--network-alias=redis"
          "--pull=missing"
        ];
      };
    };

    systemd.services = {
      nocodb-prepare = {
        description = "Prepare NocoDB storage";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        unitConfig.RequiresMountsFor = dataDir;
        script = ''
          install -d -m 0750 ${dataDir}
          install -d -m 0700 ${dataDir}/data
          install -d -m 0700 -o 999 -g 999 ${dataDir}/postgres
          install -d -m 0700 -o 999 -g 999 ${dataDir}/redis
        '';
      };

      nocodb-network = {
        description = "Create NocoDB Podman network";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.podman}/bin/podman network exists ${network} ||
            ${pkgs.podman}/bin/podman network create ${network}
        '';
      };

      "podman-nocodb-postgres" = {
        requires = [
          "nocodb-network.service"
          "nocodb-prepare.service"
        ];
        after = [
          "nocodb-network.service"
          "nocodb-prepare.service"
        ];
      };

      "podman-nocodb-redis" = {
        requires = [
          "nocodb-network.service"
          "nocodb-prepare.service"
        ];
        after = [
          "nocodb-network.service"
          "nocodb-prepare.service"
        ];
      };

      nocodb-dependencies-ready = {
        description = "Wait for NocoDB database and Redis";
        requires = [
          "podman-nocodb-postgres.service"
          "podman-nocodb-redis.service"
        ];
        after = [
          "podman-nocodb-postgres.service"
          "podman-nocodb-redis.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "3min";
        };
        script = ''
          for attempt in $(seq 1 60); do
            if ${pkgs.podman}/bin/podman exec nocodb-postgres \
              pg_isready -U nocodb -d nocodb >/dev/null 2>&1 &&
              ${pkgs.podman}/bin/podman exec nocodb-redis \
              redis-cli ping >/dev/null 2>&1; then
              exit 0
            fi
            sleep 2
          done
          exit 1
        '';
      };

      "podman-nocodb" = {
        requires = ["nocodb-dependencies-ready.service"];
        after = ["nocodb-dependencies-ready.service"];
        unitConfig.RequiresMountsFor = dataDir;
        postStart = ''
          for attempt in $(seq 1 60); do
            if ${pkgs.curl}/bin/curl -fsS \
              http://127.0.0.1:${toString cfg.port}/api/v1/health \
              >/dev/null; then
              exit 0
            fi
            sleep 2
          done
          exit 1
        '';
      };

      "podman-nocodb-worker" = {
        requires = ["podman-nocodb.service"];
        after = ["podman-nocodb.service"];
        unitConfig.RequiresMountsFor = dataDir;
      };
    };

    networking.firewall.interfaces."podman1" = {
      allowedUDPPorts = [53];
      allowedTCPPorts = [53];
    };
  };
}
