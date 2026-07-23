{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) all concatStringsSep escapeShellArgs mapAttrs mapAttrs' mapAttrsToList mkAfter mkEnableOption mkIf mkMerge mkOption nameValuePair sort types unique;
  cfg = config.laplace.services.observability;
  writers = cfg.ingress.writers;
  writerNames = builtins.attrNames writers;
  writerPorts = mapAttrsToList (_: writer: writer.metricsPort) writers;
  metricsUrl = "http://127.0.0.1:8428";
  logsUrl = "http://127.0.0.1:9428";
  alertmanagerUrl = "http://127.0.0.1:9093";
  blackboxConfig = (pkgs.formats.yaml {}).generate "blackbox.yml" {
    modules = {
      http_2xx = {
        prober = "http";
        timeout = "10s";
        http.preferred_ip_protocol = "ip4";
      };
      tcp_connect = {
        prober = "tcp";
        timeout = "10s";
      };
      icmp = {
        prober = "icmp";
        timeout = "10s";
      };
    };
  };
  localLabels = {
    host = config.networking.hostName;
    role = "observability";
    site = "home";
  };
  scrape = job_name: target: {
    inherit job_name;
    static_configs = [
      {
        targets = [target];
        labels = localLabels;
      }
    ];
  };
  ingressRelabelConfigs = mapAttrs (name: writer:
    (pkgs.formats.yaml {}).generate "vmagent-ingress-${name}-relabel.yml" [
      {
        action = "labeldrop";
        regex = "^(host|role|site)$";
      }
      {
        action = "replace";
        target_label = "host";
        replacement = name;
      }
      {
        action = "replace";
        target_label = "role";
        replacement = writer.role;
      }
      {
        action = "replace";
        target_label = "site";
        replacement = writer.site;
      }
    ])
  writers;
  ingressTls = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
      resolvers 1.1.1.1
      client_auth {
        trust_pool file /run/credentials/caddy.service/telemetry_client_ca
        verifier leaf file ${concatStringsSep " " (mapAttrsToList (name: _: "/run/credentials/caddy.service/telemetry_${name}_certificate") writers)}
      }
    }
  '';
  metricsIngressRoutes = concatStringsSep "\n" (mapAttrsToList (name: writer: let
      matcher = lib.replaceStrings ["-"] ["_"] name;
    in ''
      @${matcher}_metrics {
        method POST
        path /${name}/metrics
        remote_ip ${writer.sourceAddress}
        header Content-Type application/x-protobuf
        vars {http.request.tls.client.fingerprint} ${writer.certificateFingerprint}
      }
      handle @${matcher}_metrics {
        request_body {
          max_size 16MiB
        }
        rewrite * /api/v1/write?
        header Connection close
        reverse_proxy 127.0.0.1:${toString writer.metricsPort}
      }
    '')
    writers);
  journalIngressRoutes = concatStringsSep "\n" (mapAttrsToList (name: writer: let
      matcher = lib.replaceStrings ["-"] ["_"] name;
    in ''
      @${matcher}_journal {
        method POST
        path /${name}/journald/upload
        remote_ip ${writer.sourceAddress}
        header Content-Type application/vnd.fdo.journal
        header !Content-Encoding
        vars {http.request.tls.client.fingerprint} ${writer.certificateFingerprint}
      }
      handle @${matcher}_journal {
        request_body {
          max_size 128MiB
        }
        rewrite * /insert/journald/upload?_stream_fields=source&extra_fields=source%3D${name}
        header Connection close
        reverse_proxy 127.0.0.1:9428 {
          header_up -AccountID
          header_up -ProjectID
          header_up -VL-*
          header_up VL-Extra-Fields source=${name}
          header_up VL-Stream-Fields source
        }
      }
    '')
    writers);
in {
  options.laplace.services.observability = {
    enable = mkEnableOption "single-node homelab observability stack";

    metricsMount = mkOption {
      type = types.str;
      default = "/var/lib/private/victoriametrics";
      description = "Dedicated VictoriaMetrics filesystem mount point.";
    };

    logsMount = mkOption {
      type = types.str;
      default = "/var/lib/private/victorialogs";
      description = "Dedicated VictoriaLogs filesystem mount point.";
    };

    expectedHosts = mkOption {
      type = types.listOf types.str;
      default = [config.networking.hostName];
      description = "Hosts which must continuously deliver node-agent metrics.";
    };

    frontend = {
      enable = mkEnableOption "tailnet-only Caddy frontend";
      domain = mkOption {
        type = types.str;
        default = "observe.dysthesis.com";
      };
      email = mkOption {
        type = types.str;
        default = "dysthesis@protonmail.com";
      };
      cloudflareSopsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "SOPS file containing the Cloudflare DNS token.";
      };
    };

    ingress = {
      enable = mkEnableOption "authenticated host telemetry ingestion";
      domain = mkOption {
        type = types.str;
        default = "telemetry.dysthesis.com";
      };
      metricsPort = mkOption {
        type = types.port;
        default = 8443;
      };
      journalPort = mkOption {
        type = types.port;
        default = 8444;
      };
      caFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      writers = mkOption {
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            sourceAddress = mkOption {
              type = types.strMatching "([0-9]{1,3}\\.){3}[0-9]{1,3}";
            };
            certificateFile = mkOption {
              type = types.str;
            };
            certificateFingerprint = mkOption {
              type = types.strMatching "[0-9a-f]{64}";
            };
            role = mkOption {
              type = types.strMatching "[A-Za-z0-9_.-]+";
              default = "host";
            };
            site = mkOption {
              type = types.strMatching "[A-Za-z0-9_.-]+";
              default = "home";
            };
            metricsPort = mkOption {
              type = types.port;
            };
            maxIngestionRate = mkOption {
              type = types.ints.positive;
              default = 1000;
            };
            maxHourlySeries = mkOption {
              type = types.ints.positive;
              default = 10000;
            };
            maxDailySeries = mkOption {
              type = types.ints.positive;
              default = 20000;
            };
            metricsBytesPerSecond = mkOption {
              type = types.ints.positive;
              default = 65536;
            };
            metricsBurstBytes = mkOption {
              type = types.ints.positive;
              default = 16777216;
            };
            journalBytesPerSecond = mkOption {
              type = types.ints.positive;
              default = 65536;
            };
            journalBurstBytes = mkOption {
              type = types.ints.positive;
              default = 134217728;
            };
          };
        });
      };
    };

    opnsenseSyslog = {
      enable = mkEnableOption "OPNsense TLS syslog ingestion";
      sourceAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      certificateFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      keyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.metricsMount != cfg.logsMount;
          message = "observability metrics and logs need distinct filesystem mounts";
        }
        {
          assertion = builtins.hasAttr cfg.metricsMount config.fileSystems;
          message = "observability metrics mount ${cfg.metricsMount} must be declared in fileSystems";
        }
        {
          assertion = builtins.hasAttr cfg.logsMount config.fileSystems;
          message = "observability logs mount ${cfg.logsMount} must be declared in fileSystems";
        }
        {
          assertion = !(lib.hasPrefix "/nix/persist" cfg.metricsMount || lib.hasPrefix "/nix/persist" cfg.logsMount);
          message = "bulk telemetry must not live in Mnemosyne's root-disk persist tree";
        }
      ];

      services.victoriametrics = {
        enable = true;
        listenAddress = "127.0.0.1:8428";
        stateDir = "victoriametrics";
        retentionPeriod = "90d";
        extraOptions = [
          "-storage.minFreeDiskSpaceBytes=6GiB"
          "-maxInsertRequestSize=16MiB"
          "-maxLabelsPerTimeseries=40"
          "-maxLabelValueLen=512"
          "-influx.maxLineSize=256KiB"
          "-influx.maxRequestSize=16MiB"
        ];
        prometheusConfig = {
          global = {
            scrape_interval = "30s";
            scrape_timeout = "10s";
          };
          scrape_configs =
            [
              (scrape "victoriametrics" "127.0.0.1:8428")
              (scrape "victorialogs" "127.0.0.1:9428")
              (scrape "grafana" "127.0.0.1:3000")
              (scrape "alertmanager" "127.0.0.1:9093")
              (scrape "vmalert-metrics" "127.0.0.1:8880")
              (scrape "vmalert-logs" "127.0.0.1:8881")
              (scrape "vmagent" "127.0.0.1:8429")
              (scrape "node" "127.0.0.1:9100")
              (scrape "blackbox" "127.0.0.1:9115")
              {
                job_name = "blackbox-grafana";
                metrics_path = "/probe";
                params.module = ["http_2xx"];
                static_configs = [{targets = ["http://127.0.0.1:3000/api/health"];}];
                relabel_configs = [
                  {
                    source_labels = ["__address__"];
                    target_label = "__param_target";
                  }
                  {
                    source_labels = ["__param_target"];
                    target_label = "instance";
                  }
                  {
                    target_label = "__address__";
                    replacement = "127.0.0.1:9115";
                  }
                ];
              }
            ]
            ++ mapAttrsToList (name: writer: scrape "vmagent-ingress-${name}" "127.0.0.1:${toString writer.metricsPort}") writers;
        };
      };

      services.victorialogs = {
        enable = true;
        listenAddress = "127.0.0.1:9428";
        stateDir = "victorialogs";
        extraOptions = [
          "-retentionPeriod=30d"
          "-retention.maxDiskSpaceUsageBytes=70GiB"
          "-storage.minFreeDiskSpaceBytes=16GiB"
          "-insert.maxFieldsPerLine=64"
          "-insert.maxLineSizeBytes=256KiB"
          "-journald.streamFields=source"
          "-search.maxQueryDuration=30s"
          "-search.maxQueryLen=16KiB"
          "-search.maxQueryTimeRange=31d"
        ];
      };

      systemd.services.victoriametrics.unitConfig = {
        RequiresMountsFor = cfg.metricsMount;
        ConditionPathIsMountPoint = cfg.metricsMount;
      };
      systemd.services.victorialogs.unitConfig = {
        RequiresMountsFor = cfg.logsMount;
        ConditionPathIsMountPoint = cfg.logsMount;
      };

      services.grafana = {
        enable = true;
        declarativePlugins = [pkgs.grafanaPlugins.victoriametrics-logs-datasource];
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = 3000;
            domain = cfg.frontend.domain;
            root_url =
              if cfg.frontend.enable
              then "https://${cfg.frontend.domain}/"
              else "http://127.0.0.1:3000/";
            enforce_domain = cfg.frontend.enable;
            enable_gzip = true;
          };

          security = {
            admin_user = "admin";
            admin_password = "$__file{/var/lib/grafana/bootstrap-admin-password}";
            secret_key = "$__file{/var/lib/grafana/secret-key}";
          };
          users = {
            allow_sign_up = false;
            allow_org_create = false;
          };
          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
          };

          dashboards.default_home_dashboard_path = "${./dashboards}/fleet.json";

          metrics.enabled = true;
        };
        provision = {
          enable = true;
          datasources.settings = {
            apiVersion = 1;
            deleteDatasources = [
              {
                name = "VictoriaMetrics";
                orgId = 1;
              }
              {
                name = "VictoriaLogs";
                orgId = 1;
              }
            ];
            datasources = [
              {
                name = "VictoriaMetrics";
                uid = "victoriametrics";
                type = "prometheus";
                access = "proxy";
                url = metricsUrl;
                isDefault = true;
                editable = false;
              }
              {
                name = "VictoriaLogs";
                uid = "victorialogs";
                type = "victoriametrics-logs-datasource";
                access = "proxy";
                url = logsUrl;
                editable = false;
              }
            ];
          };
          dashboards.settings = {
            apiVersion = 1;
            providers = [
              {
                name = "Laplace";
                type = "file";
                disableDeletion = true;
                updateIntervalSeconds = 30;
                options.path = ./dashboards;
              }
            ];
          };
        };
      };

      # Bootstrap files stay local and random while Argus SOPS enrolment is
      # pending. Replace these file-provider paths with SOPS files before exposing
      # the frontend; changing secret-key later requires Grafana key rotation.
      systemd.services.grafana.preStart = lib.mkBefore ''
        umask 077
        test -s /var/lib/grafana/secret-key || ${pkgs.openssl}/bin/openssl rand -hex 32 > /var/lib/grafana/secret-key
        test -s /var/lib/grafana/bootstrap-admin-password || ${pkgs.openssl}/bin/openssl rand -hex 24 > /var/lib/grafana/bootstrap-admin-password
      '';

      systemd.services.observability-notification-test = {
        description = "Observability notification test sentinel";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
        };
      };

      services.prometheus.alertmanager = {
        enable = true;
        # URL comes from SOPS via envsubst; validate substituted config at start.
        checkConfig = false;
        listenAddress = "127.0.0.1";
        port = 9093;
        configuration = {
          global.resolve_timeout = "5m";
          route = {
            receiver = "warnings";
            group_by = ["alertname" "host"];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
            routes = [
              {
                receiver = "dead-man";
                matchers = ["alertname = \"TelemetryPipelineDeadMan\""];
                group_wait = "0s";
                group_interval = "15s";
                repeat_interval = "30s";
              }
              {
                receiver = "critical";
                matchers = ["severity = \"critical\""];
              }
            ];
          };
          receivers = [
            {
              name = "dead-man";
              webhook_configs = [
                {
                  url = "$UPTIME_KUMA_PUSH_URL";
                  send_resolved = false;
                }
              ];
            }
            {
              name = "warnings";
              webhook_configs = [
                {
                  url = "https://ntfy.dysthesis.com/alerts?template=alertmanager&priority=high&tags=warning";
                  send_resolved = true;
                  http_config.authorization = {
                    type = "Bearer";
                    credentials = "$NTFY_ALERTMANAGER_TOKEN";
                  };
                }
              ];
            }
            {
              name = "critical";
              webhook_configs = [
                {
                  url = "https://ntfy.dysthesis.com/alerts?template=alertmanager&priority=max&tags=rotating_light";
                  send_resolved = true;
                  http_config.authorization = {
                    type = "Bearer";
                    credentials = "$NTFY_ALERTMANAGER_TOKEN";
                  };
                }
              ];
            }
          ];
          inhibit_rules = [
            {
              source_matchers = ["alertname = \"TelemetryHostStale\""];
              target_matchers = ["severity = \"warning\""];
              equal = ["host"];
            }
          ];
        };
      };

      systemd.services.alertmanager.preStart = lib.mkAfter ''
        ${config.services.prometheus.alertmanager.package}/bin/amtool check-config /tmp/alert-manager-substituted.yaml
      '';

      services.vmalert.instances = {
        metrics = {
          enable = true;
          settings = {
            "datasource.url" = metricsUrl;
            "notifier.url" = [alertmanagerUrl];
            "httpListenAddr" = "127.0.0.1:8880";
            "remoteRead.url" = metricsUrl;
            "remoteWrite.url" = metricsUrl;
          };
          rules = import ./rules/metrics.nix {inherit (cfg) expectedHosts;};
        };
        logs = {
          enable = true;
          settings = {
            "datasource.url" = logsUrl;
            "notifier.url" = [alertmanagerUrl];
            "httpListenAddr" = "127.0.0.1:8881";
            "remoteRead.url" = metricsUrl;
            "remoteWrite.url" = metricsUrl;
            "rule.defaultRuleType" = "vlogs";
          };
          rules = import ./rules/logs.nix;
        };
      };

      systemd.services.vmalert-metrics = {
        after = ["victoriametrics.service" "alertmanager.service"];
        requires = ["victoriametrics.service" "alertmanager.service"];
      };
      systemd.services.vmalert-logs = {
        after = ["victorialogs.service" "victoriametrics.service" "alertmanager.service"];
        requires = ["victorialogs.service" "victoriametrics.service" "alertmanager.service"];
      };
      systemd.services.victoriametrics.wants = ["vmalert-metrics.service" "vmalert-logs.service"];
      systemd.services.victorialogs.wants = ["vmalert-logs.service"];
      systemd.services.grafana = {
        after = ["systemd-tmpfiles-setup.service" "victoriametrics.service" "victorialogs.service"];
        wants = ["victoriametrics.service" "victorialogs.service"];
      };

      services.prometheus.exporters.blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9115;
        configFile = blackboxConfig;
        openFirewall = false;
      };

      mnemosyne.dirs = [
        "/var/lib/grafana"
        "/var/lib/private/alertmanager"
        "/var/backups/grafana"
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/grafana 0750 grafana grafana -"
        "d /var/backups/grafana 0700 grafana grafana -"
      ];
      systemd.services.grafana-sqlite-backup = {
        description = "Coherent Grafana SQLite backup for PBS";
        after = ["grafana.service"];
        serviceConfig = {
          Type = "oneshot";
          User = "grafana";
          Group = "grafana";
          UMask = "0077";
        };
        script = ''
          rm -f /var/backups/grafana/grafana.db.tmp
          ${pkgs.sqlite}/bin/sqlite3 /var/lib/grafana/data/grafana.db ".backup '/var/backups/grafana/grafana.db.tmp'"
          mv /var/backups/grafana/grafana.db.tmp /var/backups/grafana/grafana.db
        '';
      };
      systemd.timers.grafana-sqlite-backup = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
    }

    (mkIf cfg.frontend.enable {
      assertions = [
        {
          assertion = cfg.frontend.cloudflareSopsFile != null;
          message = "observability frontend needs frontend.cloudflareSopsFile";
        }
      ];
      laplace.services.caddy = {
        enable = true;
        email = cfg.frontend.email;
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = cfg.frontend.cloudflareSopsFile;
          proxies.${cfg.frontend.domain} = "127.0.0.1:3000";
        };
      };
    })

    (mkIf cfg.ingress.enable {
      assertions = [
        {
          assertion = cfg.frontend.enable && cfg.frontend.cloudflareSopsFile != null;
          message = "observability ingress needs the Cloudflare-backed Caddy frontend";
        }
        {
          assertion = cfg.ingress.metricsPort != 443 && cfg.ingress.journalPort != 443 && cfg.ingress.metricsPort != cfg.ingress.journalPort;
          message = "observability metrics, journals, and Grafana need distinct listeners";
        }
        {
          assertion = cfg.ingress.caFile != null;
          message = "observability ingress needs ingress.caFile";
        }
        {
          assertion = writers != {};
          message = "observability ingress needs at least one writer";
        }
        {
          assertion = all (name: builtins.match "[a-z0-9][a-z0-9-]*" name != null) writerNames;
          message = "observability ingress writer names must be lowercase host names";
        }
        {
          assertion = builtins.length cfg.expectedHosts == builtins.length (unique cfg.expectedHosts);
          message = "observability expectedHosts must not contain duplicates";
        }
        {
          assertion = sort builtins.lessThan cfg.expectedHosts == sort builtins.lessThan ([config.networking.hostName] ++ writerNames);
          message = "observability expectedHosts must contain the local host and every ingress writer";
        }
        {
          assertion = builtins.length writerPorts == builtins.length (unique writerPorts);
          message = "observability ingress writer metric ports must be unique";
        }
        {
          assertion = all (port: !(builtins.elem port [3000 8428 8429 8880 8881 9093 9100 9115 9428])) writerPorts;
          message = "observability ingress writer metric ports collide with the central stack";
        }
        {
          assertion = config.networking.nftables.enable;
          message = "observability ingress source/rate limits require the nftables firewall backend";
        }
      ];

      services.caddy = {
        globalConfig = mkAfter ''
          servers :${toString cfg.ingress.metricsPort} {
            protocols h1
            max_header_size 16KB
            timeouts {
              read_header 5s
              read_body 30s
              write 30s
              idle 30s
            }
          }
          servers :${toString cfg.ingress.journalPort} {
            protocols h1
            max_header_size 16KB
            timeouts {
              read_header 5s
              read_body 10m
              write 30s
              idle 30s
            }
          }
        '';
        # Upload-only listeners return tiny acknowledgements or errors, so unlike
        # the browser-facing vhosts they deliberately do not encode responses.
        virtualHosts = {
          "${cfg.ingress.domain}:${toString cfg.ingress.metricsPort}".extraConfig = ''
            ${ingressTls}
            ${metricsIngressRoutes}
            handle {
              header Connection close
              respond 404
            }
          '';
          "${cfg.ingress.domain}:${toString cfg.ingress.journalPort}".extraConfig = ''
            ${ingressTls}
            ${journalIngressRoutes}
            handle {
              header Connection close
              respond 404
            }
          '';
        };
      };

      systemd.services =
        (mapAttrs' (name: writer:
          nameValuePair "vmagent-ingress-${name}" {
            description = "Bounded metrics ingress for ${name}";
            wantedBy = ["multi-user.target"];
            after = ["network.target" "victoriametrics.service"];
            serviceConfig = {
              DynamicUser = true;
              User = "vmagent-ingress-${name}";
              Group = "vmagent-ingress-${name}";
              CacheDirectory = "vmagent-ingress-${name}";
              ExecStart = escapeShellArgs [
                "${config.services.victoriametrics.package}/bin/vmagent"
                "-httpListenAddr=127.0.0.1:${toString writer.metricsPort}"
                "-remoteWrite.url=${metricsUrl}/api/v1/write"
                "-remoteWrite.tmpDataPath=%C/vmagent-ingress-${name}/remote_write_tmp"
                "-remoteWrite.relabelConfig=${ingressRelabelConfigs.${name}}"
                "-remoteWrite.maxDiskUsagePerURL=500MiB"
                "-remoteWrite.maxHourlySeries=${toString writer.maxHourlySeries}"
                "-remoteWrite.maxDailySeries=${toString writer.maxDailySeries}"
                "-remoteWrite.queues=2"
                "-maxInsertRequestSize=16MiB"
                "-maxConcurrentInserts=2"
                "-insert.maxQueueDuration=5s"
                "-maxIngestionRate=${toString writer.maxIngestionRate}"
                "-memory.allowedPercent=25"
                "-maxLabelsPerTimeseries=40"
                "-maxLabelNameLen=256"
                "-maxLabelValueLen=512"
              ];
              Restart = "on-failure";
              RestartSec = "5s";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              MemoryMax = "256M";
            };
          })
        writers)
        // {
          caddy.serviceConfig.LoadCredential =
            ["telemetry_client_ca:${cfg.ingress.caFile}"]
            ++ mapAttrsToList (name: writer: "telemetry_${name}_certificate:${writer.certificateFile}") writers;
        };

      # simplification: per-source, per-signal token buckets cap wire bytes.
      # Disable compression so journal wire bytes also bound decoded input.
      networking.nftables.tables.telemetry-ingress = {
        family = "inet";
        content = ''
          set connections {
            type ipv4_addr . inet_service
            flags dynamic
          }
          chain input {
            type filter hook input priority -10; policy accept;
            ${concatStringsSep "\n" (mapAttrsToList (_: writer: ''
              ct state new ip saddr ${writer.sourceAddress} tcp dport { ${toString cfg.ingress.metricsPort}, ${toString cfg.ingress.journalPort} } add @connections { ip saddr . tcp dport ct count over 8 } drop
              ip saddr ${writer.sourceAddress} tcp dport ${toString cfg.ingress.metricsPort} limit rate over ${toString writer.metricsBytesPerSecond} bytes/second burst ${toString writer.metricsBurstBytes} bytes drop
              ip saddr ${writer.sourceAddress} tcp dport ${toString cfg.ingress.journalPort} limit rate over ${toString writer.journalBytesPerSecond} bytes/second burst ${toString writer.journalBurstBytes} bytes drop
            '')
            writers)}
          }
        '';
      };
      networking.firewall.extraInputRules = concatStringsSep "\n" (mapAttrsToList (name: writer: ''
          ip saddr ${writer.sourceAddress} tcp dport { ${toString cfg.ingress.metricsPort}, ${toString cfg.ingress.journalPort} } ct state new limit rate over 60/minute burst 20 packets drop
          ip saddr ${writer.sourceAddress} tcp dport { ${toString cfg.ingress.metricsPort}, ${toString cfg.ingress.journalPort} } accept comment "${name} telemetry ingress"
        '')
        writers);

      mnemosyne.dirs = map (name: "/var/cache/private/vmagent-ingress-${name}") writerNames;
    })

    (mkIf cfg.opnsenseSyslog.enable {
      assertions = [
        {
          assertion = cfg.opnsenseSyslog.certificateFile != null && cfg.opnsenseSyslog.keyFile != null;
          message = "OPNsense TLS syslog needs certificateFile and keyFile";
        }
        {
          assertion = cfg.opnsenseSyslog.sourceAddress != null;
          message = "OPNsense TLS syslog needs its explicit sourceAddress";
        }
        {
          assertion = config.networking.nftables.enable;
          message = "OPNsense syslog source scoping requires the nftables firewall backend";
        }
      ];
      services.victorialogs.extraOptions = [
        "-syslog.listenAddr.tcp=0.0.0.0:6514"
        "-syslog.tls"
        "-syslog.tlsCertFile=/run/credentials/victorialogs.service/syslog_cert"
        "-syslog.tlsKeyFile=/run/credentials/victorialogs.service/syslog_key"
        "-syslog.tlsMinVersion=TLS13"
        "-syslog.extraFields.tcp={\"source\":\"opnsense\"}"
        "-syslog.streamFields.tcp=[\"source\"]"
        "-syslog.useRemoteIP.tcp"
      ];
      systemd.services.victorialogs.serviceConfig.LoadCredential = [
        "syslog_cert:${cfg.opnsenseSyslog.certificateFile}"
        "syslog_key:${cfg.opnsenseSyslog.keyFile}"
      ];
      networking.firewall.extraInputRules = mkIf (cfg.opnsenseSyslog.sourceAddress != null) ''
        ip saddr ${cfg.opnsenseSyslog.sourceAddress} tcp dport 6514 accept
      '';
    })
  ]);
}
