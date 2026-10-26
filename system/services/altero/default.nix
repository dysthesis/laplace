{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.altero;
  backupDir = "/var/backups/altero";
  database = "${cfg.dataDir}/altero.sqlite";
  containerUid = 10001;
  inherit (lib) mkEnableOption mkIf;
in {
  options.laplace.services.altero =
    {enable = mkEnableOption "Altero Zotero synchronisation server";}
    // import ./settings.nix {inherit lib;};

  config = mkIf cfg.enable {
    laplace.docker.enable = true;

    mnemosyne.dirs = [cfg.dataDir backupDir];

    virtualisation.oci-containers.containers.altero = {
      inherit (cfg) image;
      autoStart = true;
      ports = ["127.0.0.1:${toString cfg.port}:8000"];
      volumes = ["${cfg.dataDir}:/data"];
      environment = {
        ALTERO_DATABASE_URL = "sqlite+aiosqlite:////data/altero.sqlite";
        # Host-published Podman ports appear from the default bridge gateway.
        ALTERO_FORWARDED_ALLOW_IPS = "10.88.0.1";
        ALTERO_PUBLIC_URL = "https://${cfg.domain}";
      };
      extraOptions = [
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges"
      ];
    };

    systemd.tmpfiles.rules = ["d ${backupDir} 0700 root root -"];

    # The image runs as uid 10001 and writes nowhere outside /data.
    systemd.services."podman-altero" = {
      unitConfig.RequiresMountsFor = cfg.dataDir;
      preStart = lib.mkBefore ''
        ${pkgs.coreutils}/bin/install -d -m 0700 -o ${toString containerUid} -g ${toString containerUid} ${lib.escapeShellArg cfg.dataDir}
      '';
    };

    systemd.services.altero-sqlite-backup = {
      description = "Coherent Altero SQLite backup for PBS";
      unitConfig.ConditionPathExists = database;
      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
      };
      script = ''
        rm -f ${backupDir}/altero.sqlite.tmp
        ${pkgs.sqlite}/bin/sqlite3 ${lib.escapeShellArg database} ".backup '${backupDir}/altero.sqlite.tmp'"
        mv ${backupDir}/altero.sqlite.tmp ${backupDir}/altero.sqlite
      '';
    };

    systemd.timers.altero-sqlite-backup = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
