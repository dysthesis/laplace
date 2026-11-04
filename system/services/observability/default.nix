{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) all concatStringsSep escapeShellArgs mapAttrs' mapAttrsToList mkAfter mkEnableOption mkIf mkMerge mkOption nameValuePair sort types unique;
  cfg = config.laplace.services.observability;
  writers = cfg.ingress.writers;
  writerNames = builtins.attrNames writers;
  writerPorts = mapAttrsToList (_: writer: writer.metricsPort) writers;
  listeners = import ./listeners.nix;
  telemetry = lib.laplace.telemetry;
  socket = port: "${listeners.listenAddress}:${toString port}";
  metricsUrl = "http://${socket listeners.metricsPort}";
  logsUrl = "http://${socket listeners.logsPort}";
  alertmanagerUrl = "http://${socket listeners.alertmanagerPort}";
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
      endpoint = lib.laplace.telemetry.endpoints {writer = name;};
    in ''
      @${matcher}_metrics {
        method POST
        path ${endpoint.metricsPath}
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
        reverse_proxy ${socket writer.metricsPort}
      }
    '')
    writers);
  journalIngressRoutes = concatStringsSep "\n" (mapAttrsToList (name: writer: let
      matcher = lib.replaceStrings ["-"] ["_"] name;
      endpoint = lib.laplace.telemetry.endpoints {writer = name;};
    in ''
      @${matcher}_journal {
        method POST
        path ${endpoint.journalUploadPath}
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
        reverse_proxy ${socket listeners.logsPort} {
          header_up -AccountID
          header_up -ProjectID
          header_up -VL-*
          header_up VL-Extra-Fields source=${name}
          header_up VL-Stream-Fields source
        }
      }
    '')
    writers);
  # Keep the source JSON as a fixture. Change only service-specific host selectors for placement.
  # Do not change fleet metrics or journal identities.
  minecraftDashboardHost =
    if cfg.minecraftHost == null
    then "loki"
    else cfg.minecraftHost;
  minecraftHostTitle =
    lib.toUpper (builtins.substring 0 1 minecraftDashboardHost)
    + builtins.substring 1 (builtins.stringLength minecraftDashboardHost) minecraftDashboardHost;
  dashboardFiles = [
    {
      name = "fleet.json";
      path = ./dashboards/fleet.json;
    }
    {
      name = "journals.json";
      path = ./dashboards/journals.json;
    }
    {
      name = "argus.json";
      path = pkgs.writeText "argus.json" (lib.replaceStrings
        ["host=\\\"argus\\\""]
        ["host=\\\"${config.networking.hostName}\\\""]
        (builtins.readFile ./dashboards/argus.json));
    }
  ];
  minecraftDashboard = {
    name = "minecraft.json";
    path = pkgs.writeText "minecraft.json" (lib.replaceStrings
      ["loki" "Loki"] [minecraftDashboardHost minecraftHostTitle]
      (builtins.readFile ./dashboards/minecraft.json));
  };
  dashboards = pkgs.linkFarm "observability-dashboards" (dashboardFiles ++ lib.optional (cfg.minecraftHost != null) minecraftDashboard);
  dashboardSources = pkgs.linkFarm "observability-dashboard-sources" (dashboardFiles ++ [minecraftDashboard]);
  dashboardOwnership = pkgs.writeTextFile {
    name = "grafana-dashboard-ownership";
    destination = "/bin/grafana-dashboard-ownership";
    executable = true;
    text =
      "#!${pkgs.python3}/bin/python3\n"
      + lib.replaceStrings
      ["@grafanaExecutable@" "@grafanaHome@"]
      [(lib.getExe config.services.grafana.package) "${config.services.grafana.package}/share/grafana"]
      (builtins.readFile ./dashboard-ownership.py);
    meta.mainProgram = "grafana-dashboard-ownership";
  };
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

    minecraftHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Active Minecraft placement, or null to remove its dashboards and rules.";
    };
    ntfyOrigin = mkOption {
      type = types.str;
      default = "https://ntfy.dysthesis.com";
      description = "Origin of the configured ntfy alert sink.";
    };
    kumaOrigin = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Uptime Kuma origin; preserves the secret heartbeat path and query.";
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
    };

    ingress = {
      enable = mkEnableOption "authenticated host telemetry ingestion";
      domain = mkOption {
        type = types.str;
        default = lib.laplace.telemetry.domain;
      };
      metricsPort = mkOption {
        type = types.port;
        default = lib.laplace.telemetry.metricsPort;
      };
      journalPort = mkOption {
        type = types.port;
        default = lib.laplace.telemetry.journalPort;
      };
      caFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      writers = mkOption {
        default = {};
        type = types.attrsOf (types.submodule {
          options = import ./writer-options.nix {inherit lib;};
        });
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion =
            cfg.metricsMount
            == "/var/lib/private/${config.services.victoriametrics.stateDir}"
            && cfg.logsMount == "/var/lib/private/${config.services.victorialogs.stateDir}";
          message = "observability dedicated mounts must back the receivers' actual private StateDirectory paths";
        }
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

      services = {
        victoriametrics = {
          enable = true;
          listenAddress = socket listeners.metricsPort;
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
                (scrape "victoriametrics" (socket listeners.metricsPort))
                (scrape "victorialogs" (socket listeners.logsPort))
                (scrape "grafana" (socket listeners.grafanaPort))
                (scrape "alertmanager" (socket listeners.alertmanagerPort))
                (scrape "vmalert-metrics" (socket listeners.metricsAlertPort))
                (scrape "vmalert-logs" (socket listeners.logsAlertPort))
                (scrape "vmagent" "${telemetry.listenAddress}:${toString telemetry.vmagentPort}")
                (scrape "node" "${telemetry.listenAddress}:${toString telemetry.nodeExporterPort}")
                (scrape "blackbox" (socket listeners.blackboxPort))
                {
                  job_name = "blackbox-grafana";
                  metrics_path = "/probe";
                  params.module = ["http_2xx"];
                  static_configs = [{targets = ["http://${socket listeners.grafanaPort}/api/health"];}];
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
                      replacement = socket listeners.blackboxPort;
                    }
                  ];
                }
              ]
              ++ mapAttrsToList (name: writer: scrape "vmagent-ingress-${name}" (socket writer.metricsPort)) writers;
          };
        };

        victorialogs = {
          enable = true;
          listenAddress = socket listeners.logsPort;
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

        grafana = {
          enable = true;
          declarativePlugins = [pkgs.grafanaPlugins.victoriametrics-logs-datasource];
          settings = {
            server = {
              http_addr = listeners.listenAddress;
              http_port = listeners.grafanaPort;
              domain = cfg.frontend.domain;
              root_url =
                if cfg.frontend.enable
                then "https://${cfg.frontend.domain}/"
                else "http://${socket listeners.grafanaPort}/";
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

            dashboards.default_home_dashboard_path = "${dashboards}/fleet.json";

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
                  disableDeletion = false;
                  updateIntervalSeconds = 30;
                  options.path = "${config.services.grafana.dataDir}/dashboards";
                }
              ];
            };
          };
        };

        prometheus.alertmanager = {
          enable = true;
          # SOPS supplies the URL through envsubst. Validate the substituted configuration at startup.
          checkConfig = false;
          inherit (listeners) listenAddress;
          port = listeners.alertmanagerPort;
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
                    url = "${cfg.ntfyOrigin}/alerts?template=alertmanager&priority=high&tags=warning";
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
                    url = "${cfg.ntfyOrigin}/alerts?template=alertmanager&priority=max&tags=rotating_light";
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

        vmalert.instances = {
          metrics = {
            enable = true;
            settings = {
              "datasource.url" = metricsUrl;
              "notifier.url" = [alertmanagerUrl];
              "httpListenAddr" = socket listeners.metricsAlertPort;
              "remoteRead.url" = metricsUrl;
              "remoteWrite.url" = metricsUrl;
            };
            rules = import ./rules/metrics.nix {inherit (cfg) expectedHosts minecraftHost;};
          };
          logs = {
            enable = true;
            settings = {
              "datasource.url" = logsUrl;
              "notifier.url" = [alertmanagerUrl];
              "httpListenAddr" = socket listeners.logsAlertPort;
              "remoteRead.url" = metricsUrl;
              "remoteWrite.url" = metricsUrl;
              "rule.defaultRuleType" = "vlogs";
            };
            rules = import ./rules/logs.nix;
          };
        };

        prometheus.exporters.blackbox = {
          enable = true;
          inherit (listeners) listenAddress;
          port = listeners.blackboxPort;
          configFile = (pkgs.formats.yaml {}).generate "blackbox.yml" {
            modules.http_2xx = {
              prober = "http";
              timeout = "10s";
              http.preferred_ip_protocol = "ip4";
            };
          };
          openFirewall = false;
        };
      };

      mnemosyne.dirs = [
        "/var/lib/grafana"
        "/var/lib/private/alertmanager"
        "/var/backups/grafana"
      ];

      # Render once for provisioning, the home dashboard and build-time checks.
      system.build = {
        observabilityDashboards = dashboards;
        observabilityDashboardOwnership = dashboardOwnership;
      };

      systemd = {
        tmpfiles.rules = [
          "d /var/lib/grafana 0750 grafana grafana -"
          "d /var/backups/grafana 0700 grafana grafana -"
        ];
        services = {
          victoriametrics = {
            unitConfig = {
              RequiresMountsFor = cfg.metricsMount;
              ConditionPathIsMountPoint = cfg.metricsMount;
            };
            wants = ["vmalert-metrics.service" "vmalert-logs.service"];
          };
          victorialogs = {
            unitConfig = {
              RequiresMountsFor = cfg.logsMount;
              ConditionPathIsMountPoint = cfg.logsMount;
            };
            wants = ["vmalert-logs.service"];
          };
          grafana = {
            # The normal process stops before ExecStartPre runs, also on restart.
            preStart = lib.mkBefore ''
              ${lib.getExe dashboardOwnership}
            '';
            environment = {
              GRAFANA_STATE_DIR = config.services.grafana.dataDir;
              GRAFANA_DATABASE_PATH = config.services.grafana.settings.database.path;
              GRAFANA_SECRET_KEY = config.services.grafana.settings.security.secret_key;
              GRAFANA_DASHBOARD_SOURCES = "${dashboardSources}";
              GRAFANA_DASHBOARDS = "${dashboards}";
            };
            serviceConfig.TimeoutStartSec = 180;
            after = ["systemd-tmpfiles-setup.service" "victoriametrics.service" "victorialogs.service"];
            wants = ["victoriametrics.service" "victorialogs.service"];
          };
          observability-notification-test = {
            description = "Observability notification test sentinel";
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.coreutils}/bin/true";
            };
          };
          alertmanager.preStart = lib.mkMerge [
            (lib.mkIf (cfg.kumaOrigin != null) (lib.mkBefore ''
              export UPTIME_KUMA_PUSH_URL=${lib.escapeShellArg cfg.kumaOrigin}/"''${UPTIME_KUMA_PUSH_URL#*://*/}"
            ''))
            (lib.mkAfter ''
              ${config.services.prometheus.alertmanager.package}/bin/amtool check-config /tmp/alert-manager-substituted.yaml
            '')
          ];
          vmalert-metrics = {
            after = ["victoriametrics.service" "alertmanager.service"];
            requires = ["victoriametrics.service" "alertmanager.service"];
          };
          vmalert-logs = {
            after = ["victorialogs.service" "victoriametrics.service" "alertmanager.service"];
            requires = ["victorialogs.service" "victoriametrics.service" "alertmanager.service"];
          };
          grafana-sqlite-backup = {
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
        };
        timers.grafana-sqlite-backup = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    }

    (mkIf cfg.frontend.enable {
      assertions = [
        {
          assertion = config.laplace.services.caddy.enable && config.laplace.services.caddy.cloudflare.enable;
          message = "observability frontend needs the machine's Cloudflare-backed Caddy facility";
        }
      ];
      laplace.services.caddy.cloudflare.proxies.${cfg.frontend.domain} = socket listeners.grafanaPort;
    })

    (mkIf cfg.ingress.enable {
      assertions = [
        {
          assertion = cfg.frontend.enable;
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
          assertion = all (port: !(builtins.elem port ((builtins.attrValues (builtins.removeAttrs listeners ["listenAddress"])) ++ [telemetry.nodeExporterPort telemetry.vmagentPort]))) writerPorts;
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
        # Upload responses are small. Do not encode them.
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
        (mapAttrs' (name: writer: let
          relabel = (pkgs.formats.yaml {}).generate "vmagent-ingress-${name}-relabel.yml" [
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
          ];
        in
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
                "-httpListenAddr=${socket writer.metricsPort}"
                "-remoteWrite.url=${metricsUrl}/api/v1/write"
                "-remoteWrite.tmpDataPath=%C/vmagent-ingress-${name}/remote_write_tmp"
                "-remoteWrite.relabelConfig=${relabel}"
                "-remoteWrite.maxDiskUsagePerURL=500MiB"
                "-remoteWrite.maxHourlySeries=10000"
                "-remoteWrite.maxDailySeries=20000"
                "-remoteWrite.queues=2"
                "-maxInsertRequestSize=16MiB"
                "-maxConcurrentInserts=2"
                "-insert.maxQueueDuration=5s"
                "-maxIngestionRate=1000"
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

      # Token buckets limit wire bytes. Disable compression to limit decoded input.
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
              ip saddr ${writer.sourceAddress} tcp dport ${toString cfg.ingress.metricsPort} limit rate over 65536 bytes/second burst 16777216 bytes drop
              ip saddr ${writer.sourceAddress} tcp dport ${toString cfg.ingress.journalPort} limit rate over 65536 bytes/second burst 134217728 bytes drop
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
  ]);
}
