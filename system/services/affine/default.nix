{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.affine;
  backupDir = "/var/backups/affine";
  network = "affine";
  version = "0.27.4";
  affineImage = "ghcr.io/toeverything/affine:${version}@sha256:b649f5ce2384ffdf13c23bccf81d759e15973d59d0b0058af65d895a84373099";
  postgresImage = "pgvector/pgvector:pg16@sha256:ccc6e83d6e35e931dc7c5def2022729d5a6c370318d099181995567ff1fb4d6b";
  redisImage = "redis:7.4.11@sha256:71da9275c5f3fcb97d0fa0c8c5b36cc995327265420f17a04bfd544f458059f7";
  configFile = pkgs.writeText "affine-config.json" (builtins.toJSON {
    "$schema" = "https://github.com/toeverything/AFFiNE/releases/download/v${version}/config.schema.json";
    auth = {
      allowSignup = false;
      allowSignupForOauth = false;
    };
    copilot.enabled = false;
    flags.allowGuestDemoWorkspace = false;
    server = {
      name = "Dysthesis Wiki";
      externalUrl = "https://${cfg.domain}";
      host = cfg.domain;
      https = true;
    };
  });
  environment = {
    AFFINE_INDEXER_ENABLED = "false";
    DATABASE_URL = "postgresql://affine@postgres:5432/affine";
    REDIS_SERVER_HOST = "redis";
  };
  volumes = [
    "${cfg.dataDir}/storage:/root/.affine/storage"
    "${cfg.dataDir}/config:/root/.affine/config"
  ];
  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  options.laplace.services.affine = {
    enable = mkEnableOption "AFFiNE collaborative workspace";

    domain = mkOption {
      type = types.str;
      example = "wiki.example.com";
      description = "Public hostname used for AFFiNE URLs.";
    };

    port = mkOption {
      type = types.port;
      default = 3010;
      description = "Loopback port exposed to the host reverse proxy.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/affine";
      description = "Persistent AFFiNE application and PostgreSQL data.";
    };
  };

  config = mkIf cfg.enable {
    laplace.docker.enable = true;

    mnemosyne.dirs = [cfg.dataDir backupDir];

    virtualisation.oci-containers.containers = {
      affine = {
        image = affineImage;
        inherit environment volumes;
        autoStart = true;
        ports = ["127.0.0.1:${toString cfg.port}:3010"];
        extraOptions = [
          "--network=${network}"
          "--pull=missing"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
        ];
      };

      affine-postgres = {
        image = postgresImage;
        autoStart = true;
        volumes = ["${cfg.dataDir}/postgres:/var/lib/postgresql/data"];
        environment = {
          POSTGRES_DB = "affine";
          POSTGRES_HOST_AUTH_METHOD = "trust";
          POSTGRES_INITDB_ARGS = "--data-checksums";
          POSTGRES_USER = "affine";
        };
        extraOptions = [
          "--network=${network}"
          "--network-alias=postgres"
          "--pull=missing"
          "--health-cmd=pg_isready -U affine -d affine"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=5"
        ];
      };

      # simplification: ephemeral Redis can lose queued jobs; add an AOF-backed volume when queue durability is required.
      affine-redis = {
        image = redisImage;
        autoStart = true;
        extraOptions = [
          "--network=${network}"
          "--network-alias=redis"
          "--pull=missing"
          "--health-cmd=redis-cli --raw incr ping"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=5"
        ];
      };
    };

    systemd.services = {
      affine-prepare = {
        description = "Prepare AFFiNE persistent directories";
        environment.AFFINE_CONFIG_SOURCE = configFile;
        before = [
          "podman-affine.service"
          "podman-affine-postgres.service"
          "podman-affine-redis.service"
          "affine-migration.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        unitConfig.RequiresMountsFor = cfg.dataDir;
        script = ''
          ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg cfg.dataDir}
          ${pkgs.coreutils}/bin/install -d -m 0700 -o 999 -g 999 ${lib.escapeShellArg "${cfg.dataDir}/postgres"}
          ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg "${cfg.dataDir}/storage"} ${lib.escapeShellArg "${cfg.dataDir}/config"}
          ${pkgs.coreutils}/bin/install -m 0600 "$AFFINE_CONFIG_SOURCE" ${lib.escapeShellArg "${cfg.dataDir}/config/config.json"}
        '';
      };

      affine-network = {
        description = "Create the private AFFiNE Podman network";
        before = [
          "podman-affine.service"
          "podman-affine-postgres.service"
          "podman-affine-redis.service"
          "affine-migration.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        unitConfig.RequiresMountsFor = config.laplace.docker.dataDir;
        script = ''
          ${pkgs.podman}/bin/podman network exists ${network} || ${pkgs.podman}/bin/podman network create ${network}
        '';
      };

      affine-migration = {
        description = "Run AFFiNE database migrations";
        requires = [
          "affine-network.service"
          "affine-prepare.service"
          "podman-affine-postgres.service"
          "podman-affine-redis.service"
        ];
        after = [
          "affine-network.service"
          "affine-prepare.service"
          "podman-affine-postgres.service"
          "podman-affine-redis.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "10min";
        };
        unitConfig.RequiresMountsFor = cfg.dataDir;
        script = ''
          for container in affine-postgres affine-redis; do
            for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
              status=$(${pkgs.podman}/bin/podman inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || true)
              if [ "$status" = healthy ]; then
                break
              fi
              if [ "$attempt" -eq 60 ]; then
                echo "$container did not become healthy" >&2
                exit 1
              fi
              ${pkgs.coreutils}/bin/sleep 2
            done
          done

          ${pkgs.podman}/bin/podman run --rm \
            --name affine-migration \
            --network=${network} \
            --pull=missing \
            --cap-drop=ALL \
            --security-opt=no-new-privileges \
            ${lib.concatMapStringsSep " " (name: "--env ${name}=${lib.escapeShellArg environment.${name}}") (builtins.attrNames environment)} \
            ${lib.concatMapStringsSep " " (volume: "--volume ${lib.escapeShellArg volume}") volumes} \
            ${lib.escapeShellArg affineImage} \
            node ./scripts/self-host-predeploy.js
        '';
      };

      "podman-affine" = {
        requires = ["affine-network.service" "affine-prepare.service" "affine-migration.service"];
        after = ["affine-network.service" "affine-prepare.service" "affine-migration.service"];
        unitConfig.RequiresMountsFor = cfg.dataDir;
        serviceConfig.TimeoutStartSec = "3min";
        # Migration success is a separate hard dependency; this only checks serving readiness.
        postStart = ''
          for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
            if ${pkgs.curl}/bin/curl --fail --silent --show-error http://127.0.0.1:${toString cfg.port}/ >/dev/null; then
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 2
          done
          echo "AFFiNE did not become ready" >&2
          exit 1
        '';
      };

      "podman-affine-postgres" = {
        requires = ["affine-network.service" "affine-prepare.service"];
        after = ["affine-network.service" "affine-prepare.service"];
        unitConfig.RequiresMountsFor = cfg.dataDir;
      };

      "podman-affine-redis" = {
        requires = ["affine-network.service" "affine-prepare.service"];
        after = ["affine-network.service" "affine-prepare.service"];
      };

      affine-postgres-backup = {
        description = "Validated AFFiNE PostgreSQL backup";
        requires = ["affine-migration.service"];
        after = ["affine-migration.service"];
        unitConfig.RequiresMountsFor = "${cfg.dataDir} ${backupDir}";
        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
        };
        script = ''
          stamp=$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)
          temporary=$(${pkgs.coreutils}/bin/mktemp ${backupDir}/.affine-XXXXXXXX.dump)
          trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

          ${pkgs.podman}/bin/podman exec affine-postgres pg_dump --username=affine --dbname=affine --format=custom >"$temporary"
          ${pkgs.postgresql_16}/bin/pg_restore --list "$temporary" >/dev/null
          ${pkgs.coreutils}/bin/mv "$temporary" "${backupDir}/affine-$stamp.dump"
          trap - EXIT
          ${pkgs.findutils}/bin/find ${backupDir} -type f -name 'affine-*.dump' -mtime +13 -delete
        '';
      };
    };

    systemd.tmpfiles.rules = ["d ${backupDir} 0700 root root -"];

    systemd.timers.affine-postgres-backup = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
