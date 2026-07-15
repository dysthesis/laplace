{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption optionalAttrs optionals types;
  cfg = config.laplace.services.telemetry;
  hostName = config.networking.hostName;
  uploadSettings =
    {
      URL = cfg.journal.url;
      NetworkTimeoutSec = cfg.journal.networkTimeoutSec;
      TrustedCertificateFile = cfg.journal.trustFile;
      Compression = false;
      Header = [
        "VL-Extra-Fields: source=${hostName}"
        "VL-Stream-Fields: source"
      ];
    }
    // optionalAttrs (cfg.journal.keyFile != null) {
      ServerKeyFile = "/run/credentials/systemd-journal-upload.service/client_key";
      ServerCertificateFile = "/run/credentials/systemd-journal-upload.service/client_certificate";
    };
in {
  options.laplace.services.telemetry = {
    enable = mkEnableOption "bounded host metrics and journal forwarding";
    role = mkOption {
      type = types.str;
      default = "host";
    };
    site = mkOption {
      type = types.str;
      default = "home";
    };

    metrics = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      remoteWriteUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      basicAuthUsername = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      basicAuthPasswordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      keyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      certificateFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      queueSize = mkOption {
        type = types.str;
        default = "500MiB";
      };
      maxHourlySeries = mkOption {
        type = types.ints.positive;
        default = 10000;
      };
      maxDailySeries = mkOption {
        type = types.ints.positive;
        default = 20000;
      };
    };

    journal = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      trustFile = mkOption {
        type = types.str;
        default = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      keyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      certificateFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      maxUse = mkOption {
        type = types.str;
        default = "64M";
      };
      networkTimeoutSec = mkOption {
        type = types.str;
        default = "10m";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.metrics.enable || cfg.metrics.remoteWriteUrl != null;
          message = "telemetry metrics need metrics.remoteWriteUrl";
        }
        {
          assertion = !cfg.journal.enable || cfg.journal.url != null;
          message = "telemetry journal upload needs journal.url";
        }
        {
          assertion = (cfg.metrics.basicAuthUsername == null) == (cfg.metrics.basicAuthPasswordFile == null);
          message = "telemetry metric basic-auth username and password file must be set together";
        }
        {
          assertion = (cfg.metrics.keyFile == null) == (cfg.metrics.certificateFile == null);
          message = "telemetry metric TLS client key and certificate must be set together";
        }
        {
          assertion = (cfg.journal.keyFile == null) == (cfg.journal.certificateFile == null);
          message = "telemetry journal TLS client key and certificate must be set together";
        }
        {
          assertion = cfg.metrics.certificateFile == null || (cfg.metrics.remoteWriteUrl != null && lib.hasPrefix "https://" cfg.metrics.remoteWriteUrl);
          message = "telemetry metric TLS client certificate needs an HTTPS remote-write URL";
        }
        {
          assertion = cfg.journal.certificateFile == null || (cfg.journal.url != null && lib.hasPrefix "https://" cfg.journal.url);
          message = "telemetry journal TLS client certificate needs an HTTPS upload URL";
        }
      ];

      services.journald = {
        storage = "persistent";
        extraConfig = lib.mkForce ''
          SystemMaxUse=${cfg.journal.maxUse}
          RuntimeMaxUse=16M
          Compress=yes
        '';
        upload = mkIf cfg.journal.enable {
          enable = true;
          settings.Upload = uploadSettings;
        };
      };

      systemd.services.systemd-journal-upload.serviceConfig.LoadCredential = optionals (cfg.journal.keyFile != null) [
        "client_key:${cfg.journal.keyFile}"
        "client_certificate:${cfg.journal.certificateFile}"
      ];
      systemd.services.systemd-journal-upload.unitConfig.RequiresMountsFor = "/var/lib/private/systemd/journal-upload";
      systemd.services.telemetry-journal-ready = {
        description = "Prepare persistent journal permissions";
        requiredBy = ["systemd-journald.service"];
        before = ["systemd-journald.service"];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var/log/journal";
        };
        serviceConfig.Type = "oneshot";
        script = ''
          chown root:systemd-journal /var/log/journal
          chmod 2755 /var/log/journal
        '';
      };
      systemd.tmpfiles.rules = ["d /var/log/journal 2755 root systemd-journal -"];

      mnemosyne.dirs = [
        "/var/log/journal"
        "/var/lib/private/systemd/journal-upload"
      ];
    }

    (mkIf cfg.metrics.enable {
      services.prometheus.exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9100;
        enabledCollectors = ["systemd"];
        openFirewall = false;
      };

      services.vmagent = {
        enable = true;
        openFirewall = false;
        remoteWrite = {
          url = cfg.metrics.remoteWriteUrl;
          inherit (cfg.metrics) basicAuthUsername basicAuthPasswordFile;
        };
        prometheusConfig = {
          global = {
            scrape_interval = "30s";
            scrape_timeout = "10s";
            external_labels = {
              host = hostName;
              inherit (cfg) role site;
            };
          };
          scrape_configs = [
            {
              job_name = "node-agent";
              sample_limit = 10000;
              label_limit = 40;
              static_configs = [{targets = ["127.0.0.1:9100"];}];
            }
          ];
        };
        extraArgs =
          [
            "-httpListenAddr=127.0.0.1:8429"
            "-remoteWrite.maxDiskUsagePerURL=${cfg.metrics.queueSize}"
            "-remoteWrite.maxHourlySeries=${toString cfg.metrics.maxHourlySeries}"
            "-remoteWrite.maxDailySeries=${toString cfg.metrics.maxDailySeries}"
            "-promscrape.maxScrapeSize=8MiB"
            "-memory.allowedPercent=25"
            "-maxLabelsPerTimeseries=40"
            "-maxLabelValueLen=512"
          ]
          ++ optionals (cfg.metrics.keyFile != null) [
            "-remoteWrite.tlsKeyFile=/run/credentials/vmagent.service/client_key"
            "-remoteWrite.tlsCertFile=/run/credentials/vmagent.service/client_certificate"
          ];
      };

      systemd.services.vmagent.serviceConfig.LoadCredential = optionals (cfg.metrics.keyFile != null) [
        "client_key:${cfg.metrics.keyFile}"
        "client_certificate:${cfg.metrics.certificateFile}"
      ];
      systemd.services.vmagent.serviceConfig.MemoryMax = "128M";
      systemd.services.vmagent.unitConfig.RequiresMountsFor = "/var/cache/private/vmagent";

      mnemosyne.dirs = ["/var/cache/private/vmagent"];
    })
  ]);
}
