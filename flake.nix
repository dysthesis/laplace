{
  description = "A pursuit of order.";

  outputs = inputs @ {
    self,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    inherit (builtins) mapAttrs;
    lib = import ./nix/lib nixpkgs;

    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ];

    forAllSystems = lib.laplace.forAllSystems {
      inherit systems;
      overlays = [self.overlays.linux-hardened];
    };

    treefmt =
      forAllSystems
      (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/formatters);
    hosts = import ./hosts {inherit self lib inputs;};
    inherit (hosts) nixosConfigurations;
  in
    mapAttrs (_: forAllSystems)
    {
      devShells = pkgs: let
        nixpkgs-unstable = import inputs.nixpkgs-unstable {system = pkgs.stdenv.hostPlatform.system;};
      in {default = import ./nix/shell inputs nixpkgs-unstable;};

      packages = pkgs:
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux
        {
          linux-hardened = pkgs.linux_hardened;
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          linux-hardened-boot-test = import ./nix/tests/linux-hardened-boot.nix {inherit pkgs;};
        };

      apps = pkgs:
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          bench = {
            type = "app";
            program = lib.getExe (import ./bench pkgs);
          };
        };
      formatter = pkgs: treefmt.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper;
      checks = pkgs:
        {
          formatting = treefmt.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          # Selected sessions provide their own validation commands.
          desktop-stack = let
            validateHost = name: host:
              lib.optionalString (host.config.laplace.display.checkCommands != []) ''
                echo "validating ${name}"
                ${lib.concatStrings host.config.laplace.display.checkCommands}
              '';
          in
            pkgs.runCommand "desktop-configs" {} ''
              ${lib.concatStrings (lib.mapAttrsToList validateHost nixosConfigurations)}
              touch $out
            '';

          mk-wrapper = let
            argumentCheck = pkgs.writeShellScriptBin "argument check" ''
              test "$#" -eq 2
              test "$1" = "complex command"
              test "$2" = "--literal"
            '';
            wrapped = lib.laplace.pkgs.mkWrapper pkgs argumentCheck {
              program = "argument check";
              addFlags = ["complex command" "--literal"];
            };
            bashWrapped = lib.laplace.pkgs.mkWrapper pkgs pkgs.bash {};
          in
            assert bashWrapped.meta.outputsToInstall == ["out"];
              pkgs.runCommand "mk-wrapper-check" {} ''
                "${wrapped}/bin/argument check"
                test -e ${bashWrapped}/share/man/man1/bash.1.gz
                touch $out
              '';

          minecraft-maintenance = let
            services = nixosConfigurations.loki.config.systemd.services;
            snapshot = pkgs.writeText "mc-world-snapshot.sh" services.mc-world-snapshot.script;
            restart = pkgs.writeText "mc-nightly-restart.sh" services.mc-nightly-restart.script;
          in
            pkgs.runCommand "minecraft-maintenance-check" {nativeBuildInputs = [pkgs.bash];} ''
              bash -n ${snapshot}
              bash -n ${restart}

              trap_line=$(grep -nF 'trap restore_saves EXIT' ${snapshot} | cut -d: -f1)
              armed_line=$(grep -nF 'saves_disabled=true' ${snapshot} | cut -d: -f1)
              save_off_line=$(grep -nF "printf '%s\n' 'save-off' >&8" ${snapshot} | cut -d: -f1)
              snapshot_line=$(grep -nF 'btrfs subvolume snapshot' ${snapshot} | cut -d: -f1)
              restore_line=$(grep -nFx 'restore_saves' ${snapshot} | cut -d: -f1)
              test "$trap_line" -lt "$save_off_line"
              test "$armed_line" -lt "$save_off_line"
              test "$save_off_line" -lt "$snapshot_line"
              test "$snapshot_line" -lt "$restore_line"
              grep -Fq "'save-on' >&8" ${snapshot}
              grep -Fq '_SYSTEMD_INVOCATION_ID=$invocation_id' ${snapshot}
              grep -Fq -- '--after-cursor="$cursor"' ${snapshot}
              grep -Fq 'Automatic saving is now disabled' ${snapshot}
              grep -Fq 'Saved the game$' ${snapshot}
              grep -Fq 'data get storage $marker' ${snapshot}
              grep -Fq 'Unable to save the game' ${snapshot}
              test ${lib.escapeShellArg services.mc-world-snapshot.serviceConfig.TimeoutStartSec} = 5min
              test ${lib.escapeShellArg services.mc-nightly-restart.serviceConfig.TimeoutStartSec} = 5min

              for script in ${snapshot} ${restart}; do
                grep -Fqx 'exec 9>"/run/lock/minecraft-maintenance.lock"' "$script"
                grep -Fqx 'flock --exclusive 9' "$script"
              done
              touch $out
            '';

          minecraft-runtime = let
            runtime = pkgs.temurin-bin-17;
            minecraft = nixosConfigurations.loki.config.laplace.services.minecraft.retirement-home;
            server = nixosConfigurations.loki.config.services.minecraft-servers.servers.retirement-home;
            # Preserve production Xmx for G1 ergonomics, but limit AlwaysPreTouch in CI.
            smokeJvmOpts = builtins.replaceStrings ["-Xms${toString minecraft.memoryGb}G"] ["-Xms128M"] server.jvmOpts;
          in
            assert lib.versionAtLeast runtime.version "17.0.19";
            assert lib.versionOlder runtime.version "18";
              pkgs.runCommand "minecraft-runtime-check" {} ''
                grep -Fq 'exec ${runtime}/bin/java ' ${server.package}/bin/minecraft-server
                ${runtime}/bin/java ${smokeJvmOpts} -version >java-version 2>&1
                grep -Fq 'Temurin-17.' java-version
                touch $out
              '';

          minecraft-config-staging = let
            services = nixosConfigurations.loki.config.systemd.services;
            server = services."minecraft-server-retirement-home";
            restart = pkgs.writeText "mc-nightly-restart.sh" services.mc-nightly-restart.script;
          in
            assert !server.reloadIfChanged;
            assert !server.restartIfChanged;
              pkgs.runCommand "minecraft-config-staging-check" {} ''
                grep -Fqx 'systemctl try-restart "$unit"' ${restart}
                touch $out
              '';

          # configtest needs writable state, so the sandbox redirects it to $TMPDIR.
          # checkTailnet covers static rules; reconciliation needs network access.
          headscale-policy = let
            headscalePackage = nixosConfigurations.bifrost.config.services.headscale.package;
          in
            pkgs.runCommand "headscale-policy-check"
            {
              nativeBuildInputs = [headscalePackage];
            } ''
              config="$TMPDIR/headscale.yaml"
              cp ${nixosConfigurations.bifrost.config.services.headscale.configFile} "$config"
              substituteInPlace "$config" \
                --replace-fail /var/lib/headscale "$TMPDIR/state" \
                --replace-fail /run/headscale "$TMPDIR/run"
              mkdir -p "$TMPDIR/state" "$TMPDIR/run"

              headscale --force configtest --config "$config"
              headscale --force policy check \
                --bypass-grpc-and-access-database-directly \
                --config "$config" \
                --file ${nixosConfigurations.bifrost.config.laplace.services.headscale.acl.policyFile}
              touch $out
            '';

          tailnet-reconcile = pkgs.runCommand "tailnet-reconcile-check" {nativeBuildInputs = [pkgs.jq];} ''
            ssot='{
              "alpha":{"ip":"100.64.0.1","ip6":"fd7a:115c:a1e0::1","tags":["infra","monitor"]},
              "beta":{"ip":"100.64.0.2","ip6":"fd7a:115c:a1e0::2","tags":["infra"]}
            }'
            problems=$(jq -r --argjson ssot "$ssot" -f ${./system/tailnet/reconcile.jq} <<'JSON'
            [
              {
                "name":"wrong-name",
                "given_name":"alpha",
                "ip_addresses":["100.64.0.9","fd7a:115c:a1e0::9"],
                "tags":["tag:infra"]
              },
              {
                "name":"gamma",
                "given_name":"gamma",
                "ip_addresses":["100.64.0.3","fd7a:115c:a1e0::3"],
                "tags":["tag:game"]
              },
              {
                "name":"guest",
                "given_name":"guest",
                "ip_addresses":["100.64.0.4","fd7a:115c:a1e0::4"],
                "tags":[]
              },
              {
                "name":"guest-copy",
                "given_name":"guest",
                "ip_addresses":["100.64.0.5","fd7a:115c:a1e0::5"],
                "tags":[]
              }
            ]
            JSON
            )
            expected=$(printf '%s\n' \
              'TAG DRIFT alpha: live=infra ssot=infra,monitor' \
              'ADDRESS DRIFT alpha: live=100.64.0.9,fd7a:115c:a1e0::9 ssot=100.64.0.1,fd7a:115c:a1e0::1' \
              'MISSING from tailnet: beta' \
              'UNEXPECTED tagged tailnet node: gamma' \
              'DUPLICATE tailnet node identity: guest')
            test "$problems" = "$expected"
            touch $out
          '';

          affine-service = let
            fixture =
              (lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                  ./system/docker
                  ./system/services/affine
                  ({lib, ...}: {
                    options.mnemosyne.dirs = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [];
                    };
                    config = {
                      laplace.services.affine = {
                        enable = true;
                        domain = "wiki.example.test";
                        dataDir = "/srv/affine";
                      };
                      system.stateVersion = "26.05";
                    };
                  })
                ];
              }).config;
            containers = fixture.virtualisation.oci-containers.containers;
            services = fixture.systemd.services;
            timer = fixture.systemd.timers.affine-postgres-backup;
            configFile = services.affine-prepare.environment.AFFINE_CONFIG_SOURCE;
            pinned = image: builtins.match ".+@sha256:[0-9a-f]{64}" image != null;
          in
            assert lib.all pinned [containers.affine.image containers.affine-postgres.image containers.affine-redis.image];
            assert containers.affine.ports == ["127.0.0.1:3010:3010"];
            assert containers.affine-postgres.ports == [];
            assert containers.affine-redis.ports == [];
            assert containers.affine.volumes
            == [
              "/srv/affine/storage:/root/.affine/storage"
              "/srv/affine/config:/root/.affine/config"
            ];
            assert containers.affine-postgres.volumes == ["/srv/affine/postgres:/var/lib/postgresql/data"];
            assert builtins.elem "affine-migration.service" services.podman-affine.requires;
            assert builtins.elem "affine-migration.service" services.podman-affine.after;
            assert lib.all (unit: builtins.elem unit services.affine-migration.requires) [
              "podman-affine-postgres.service"
              "podman-affine-redis.service"
            ];
            assert lib.all (path: builtins.elem path fixture.mnemosyne.dirs) ["/srv/affine" "/var/backups/affine"];
            assert timer.timerConfig.OnCalendar == "daily";
            assert timer.timerConfig.Persistent;
            assert builtins.elem "timers.target" timer.wantedBy;
            assert services.affine-postgres-backup.serviceConfig.Type == "oneshot";
            assert services.affine-postgres-backup.serviceConfig.UMask == "0077";
            assert builtins.elem "affine-migration.service" services.affine-postgres-backup.requires;
            assert builtins.elem "affine-migration.service" services.affine-postgres-backup.after;
            assert services.affine-postgres-backup.unitConfig.RequiresMountsFor == "/srv/affine /var/backups/affine";
              pkgs.runCommand "affine-service-check" {nativeBuildInputs = [pkgs.jq];} ''
                jq -e '
                  .server.name == "Dysthesis Wiki"
                  and .server.externalUrl == "https://wiki.example.test"
                  and .server.host == "wiki.example.test"
                  and .server.https == true
                  and .auth.allowSignup == false
                  and .auth.allowSignupForOauth == false
                  and .flags.allowGuestDemoWorkspace == false
                  and .copilot.enabled == false
                ' ${configFile}
                touch $out
              '';

          telemetry-boot-persistence = let
            talos = nixosConfigurations.talos.config;
            ready = talos.systemd.services.telemetry-journal-ready;
            vmagent = talos.systemd.services.vmagent;
            journalUpload = talos.systemd.services.systemd-journal-upload;
            scripts = pkgs.writeText "telemetry-boot-persistence-scripts" ''
              ${talos.boot.initrd.systemd.services.make-source-of-persistent-dirs.script}
              ${talos.system.activationScripts.script}
            '';
          in
            pkgs.runCommand "telemetry-boot-persistence-check" {} ''
              test ${lib.escapeShellArg (lib.boolToString ready.unitConfig.DefaultDependencies)} = false
              test ${lib.escapeShellArg vmagent.unitConfig.RequiresMountsFor} = /var/cache/private/vmagent
              test ${lib.escapeShellArg journalUpload.unitConfig.RequiresMountsFor} = /var/lib/private/systemd/journal-upload
              grep -Fq /nix/persist/etc/machine-id ${scripts}
              touch $out
            '';

          telemetry-endpoint-contract = let
            endpoints = lib.laplace.telemetry.endpoints;
            talosConfigWith = settings:
              (nixosConfigurations.talos.extendModules {
                modules = [{laplace.services.telemetry = settings;}];
              }).config;
            telemetryWith = settings: (talosConfigWith settings).laplace.services.telemetry;
            metricsOverride = telemetryWith {
              metrics.origin = "https://metrics.example.net/";
              metrics.remoteWriteUrl = "https://metrics.example.net/write";
            };
            journalOverride = telemetryWith {
              journal.origin = "https://logs.example.net/";
              journal.url = "https://logs.example.net/journald";
            };
            metricsDisabled = telemetryWith {
              metrics.enable = false;
              metrics.origin = "https://metrics.example.net/";
            };
            journalDisabled = telemetryWith {
              journal.enable = false;
              journal.origin = "https://logs.example.net/";
            };
            paths = endpoints {
              writer = "canary";
              metricsOrigin = "https://metrics.example.net/";
              journalOrigin = "https://logs.example.net/";
            };
            badMetrics = builtins.tryEval ((endpoints {
              writer = "talos";
              metricsOrigin = "https://metrics.example.net/";
            }).metricsUrl);
            badJournal = builtins.tryEval ((endpoints {
              writer = "talos";
              journalOrigin = "https://logs.example.net/";
            }).journalBaseUrl);
            badWriter = builtins.tryEval ((endpoints {writer = "not/a-writer";}).journalUploadPath);
            alternate = talosConfigWith {
              writer = "canary";
              metrics.origin = "https://metrics.example.net:10443";
              journal.origin = "https://logs.example.net:10444";
            };
            fullOverrides = talosConfigWith {
              writer = "canary";
              metrics.origin = "https://metrics.example.net:10443";
              journal.origin = "https://logs.example.net:10444";
              metrics.remoteWriteUrl = "https://override.example.net/remote/write?tenant=1";
              journal.url = "https://override.example.net/archive/journald/";
            };
            canaryReceiver =
              (nixosConfigurations.argus.extendModules {
                modules = [
                  {
                    laplace.services.observability = {
                      expectedHosts = lib.mkAfter ["canary"];
                      ingress.writers.canary = {
                        sourceAddress = "10.0.80.3";
                        certificateFile = "/fixture/canary.crt";
                        certificateFingerprint = "0000000000000000000000000000000000000000000000000000000000000000";
                        metricsPort = 8440;
                      };
                    };
                  }
                ];
              }).config.services.caddy.virtualHosts;
            isolatedAssertions = settings:
              (lib.evalModules {
                specialArgs.pkgs = {cacert = "/fixture/cacert";};
                modules = [
                  ./system/services/telemetry
                  {
                    options = {
                      networking.hostName = lib.mkOption {
                        type = lib.types.str;
                        default = "talos";
                      };
                      services = lib.mkOption {
                        type = lib.types.attrsOf lib.types.anything;
                        default = {};
                      };
                      systemd = lib.mkOption {
                        type = lib.types.attrsOf lib.types.anything;
                        default = {};
                      };
                      mnemosyne.dirs = lib.mkOption {
                        type = lib.types.listOf lib.types.str;
                        default = [];
                      };
                      assertions = lib.mkOption {
                        type = lib.types.listOf lib.types.anything;
                        default = [];
                      };
                    };
                    config.laplace.services.telemetry = settings;
                  }
                ];
              }).config.assertions;
            disabledMetricsAssertions = isolatedAssertions {
              enable = true;
              metrics = {
                enable = false;
                origin = "https://metrics.example.net/";
                keyFile = "/fixture/metrics.key";
                certificateFile = "/fixture/metrics.crt";
              };
              journal.enable = false;
            };
            disabledJournalAssertions = isolatedAssertions {
              enable = true;
              metrics.enable = false;
              journal = {
                enable = false;
                origin = "https://logs.example.net/";
                keyFile = "/fixture/journal.key";
                certificateFile = "/fixture/journal.crt";
              };
            };
            enabledMetricHttp = isolatedAssertions {
              enable = true;
              metrics = {
                remoteWriteUrl = "http://127.0.0.1:18844/write";
                keyFile = "/fixture/metrics.key";
                certificateFile = "/fixture/metrics.crt";
              };
              journal.enable = false;
            };
            enabledJournalHttp = isolatedAssertions {
              enable = true;
              metrics.enable = false;
              journal = {
                url = "http://127.0.0.1:18844/journald";
                keyFile = "/fixture/journal.key";
                certificateFile = "/fixture/journal.crt";
              };
            };
            disabledUnpaired = isolatedAssertions {
              enable = true;
              metrics = {
                enable = false;
                certificateFile = "/fixture/metrics.crt";
              };
              journal.enable = false;
            };
            enabledNull = isolatedAssertions {
              enable = true;
              metrics.remoteWriteUrl = null;
              journal.enable = false;
            };
          in
            assert lib.all (a: a.assertion) disabledMetricsAssertions;
            assert lib.all (a: a.assertion) disabledJournalAssertions;
            assert !(lib.all (a: a.assertion) enabledMetricHttp);
            assert !(lib.all (a: a.assertion) enabledJournalHttp);
            assert !(lib.all (a: a.assertion) disabledUnpaired);
            assert !(lib.all (a: a.assertion) enabledNull);
            assert alternate.services.vmagent.remoteWrite.url == "https://metrics.example.net:10443/canary/metrics";
            assert alternate.services.journald.upload.settings.Upload.URL == "https://logs.example.net:10444/canary/journald";
            assert alternate.services.vmagent.prometheusConfig.global.external_labels.host == "talos";
            assert builtins.elem "VL-Extra-Fields: source=talos" alternate.services.journald.upload.settings.Upload.Header;
            assert fullOverrides.services.vmagent.remoteWrite.url == "https://override.example.net/remote/write?tenant=1";
            assert fullOverrides.services.journald.upload.settings.Upload.URL == "https://override.example.net/archive/journald/";
            assert lib.hasInfix "path /canary/metrics\n" canaryReceiver."telemetry.dysthesis.com:8443".extraConfig;
            assert lib.hasInfix "path /canary/journald/upload\n" canaryReceiver."telemetry.dysthesis.com:8444".extraConfig;
            assert metricsOverride.journal.url == "https://telemetry.dysthesis.com:8444/talos/journald";
            assert journalOverride.metrics.remoteWriteUrl == "https://telemetry.dysthesis.com:8443/talos/metrics";
            assert metricsDisabled.journal.url == "https://telemetry.dysthesis.com:8444/talos/journald";
            assert journalDisabled.metrics.remoteWriteUrl == "https://telemetry.dysthesis.com:8443/talos/metrics";
            assert paths.metricsPath == "/canary/metrics";
            assert paths.journalUploadPath == "/canary/journald/upload";
            assert !badMetrics.success;
            assert !badJournal.success;
            assert !badWriter.success;
              pkgs.runCommand "telemetry-endpoint-contract-check" {} "touch $out";

          observability-dashboards = let
            dashboards = ./system/services/observability/dashboards;
            vmalert = nixosConfigurations.argus.config.services.vmalert.package;
          in
            pkgs.runCommand "observability-dashboards-check" {nativeBuildInputs = [pkgs.jq vmalert];} ''
              jq -s -e '
                length > 0
                and ((map(.uid) | length) == (map(.uid) | unique | length))
                and all(.[];
                  (.uid | type == "string" and length > 0)
                  and (.title | type == "string" and length > 0)
                  and (([.panels[].id] | length) == ([.panels[].id] | unique | length))
                  and all(.panels[];
                    (.datasource.uid == "victoriametrics" or .datasource.uid == "victorialogs")
                    and all(.targets[]; .expr | type == "string" and length > 0)
                  )
                )
              ' ${dashboards}/*.json

              jq -s '
                [
                  .[].panels[]
                  | select(.datasource.uid == "victoriametrics")
                  | .targets[].expr
                  | gsub("\\$__rate_interval"; "5m")
                  | gsub("\\$__range"; "1h")
                  | gsub("\\$host"; ".*")
                ]
                | to_entries
                | {groups: [{name: "dashboard-promql", rules: map({
                    record: ("dashboard_query_" + (.key | tostring)),
                    expr: .value
                  })}]}
              ' ${dashboards}/*.json > dashboard-promql.json
              vmalert -rule=dashboard-promql.json -dryRun

              jq -s '
                [
                  .[].panels[]
                  | select(.datasource.uid == "victorialogs")
                  | .targets[]
                  | select(.queryType == "stats" or .queryType == "statsRange")
                  | .expr
                  | gsub("\\$source"; "*")
                  | gsub(" \\| \\$\\{filter:raw\\}"; "")
                ]
                | to_entries
                | {groups: [{name: "dashboard-logsql", rules: map({
                    alert: ("DashboardLogQuery" + (.key | tostring)),
                    expr: .value
                  })}]}
              ' ${dashboards}/*.json > dashboard-logsql.json
              vmalert -rule=dashboard-logsql.json -rule.defaultRuleType=vlogs -dryRun
              touch $out
            '';

          observability-rules = let
            argus = nixosConfigurations.argus.config;
            vmalert = argus.services.vmalert.package;
            metricsRules = argus.environment.etc."vmalert-metrics/rules.yml".source;
            logsRules = argus.environment.etc."vmalert-logs/rules.yml".source;
            alertmanagerConfig = pkgs.writeText "alertmanager.json" (builtins.toJSON argus.services.prometheus.alertmanager.configuration);
            alertmanager = argus.services.prometheus.alertmanager.package;
            notificationTest = argus.systemd.services.observability-notification-test;
            metricsRulesTest = pkgs.writeText "observability-metrics-rules-test.yml" ''
              rule_files:
                - ${metricsRules}
              evaluation_interval: 30s
              tests:
                - name: warning thresholds
                  interval: 30s
                  input_series:
                    - series: 'vm_free_disk_space_bytes{host="argus",path="/metrics"}'
                      values: "7247757312+0x24"
                    - series: 'vl_free_disk_space_bytes{host="argus",path="/logs"}'
                      values: "20401094656+0x24"
                  alert_rule_test:
                    - eval_time: 11m
                      groupname: argus-self
                      alertname: ArgusFilesystemLow
                      exp_alerts:
                        - exp_labels:
                            host: argus
                            path: /metrics
                            severity: warning
                          exp_annotations:
                            summary: Low free space on /metrics
                            description: Free space is below its store-specific warning threshold; check measured growth and retention.
                        - exp_labels:
                            host: argus
                            path: /logs
                            severity: warning
                          exp_annotations:
                            summary: Low free space on /logs
                            description: Free space is below its store-specific warning threshold; check measured growth and retention.
                    - eval_time: 11m
                      groupname: argus-self
                      alertname: ArgusFilesystemCritical
                      exp_alerts: []
                - name: critical thresholds
                  interval: 30s
                  input_series:
                    - series: 'vm_free_disk_space_bytes{host="argus",path="/metrics"}'
                      values: "6710886400+0x24"
                    - series: 'vl_free_disk_space_bytes{host="argus",path="/logs"}'
                      values: "18253611008+0x24"
                  alert_rule_test:
                    - eval_time: 11m
                      groupname: argus-self
                      alertname: ArgusFilesystemLow
                      exp_alerts: []
                    - eval_time: 11m
                      groupname: argus-self
                      alertname: ArgusFilesystemCritical
                      exp_alerts:
                        - exp_labels:
                            host: argus
                            path: /metrics
                            severity: critical
                          exp_annotations:
                            summary: Critically low free space on /metrics
                            description: Act before the backend reaches its minimum-free reserve and rejects writes.
                        - exp_labels:
                            host: argus
                            path: /logs
                            severity: critical
                          exp_annotations:
                            summary: Critically low free space on /logs
                            description: Act before the backend reaches its minimum-free reserve and rejects writes.
                - name: fleet storage warning ignores pseudo-filesystems
                  interval: 1m
                  input_series:
                    - series: 'node_filesystem_avail_bytes{host="loki",job="node-agent",device="/dev/vda3",fstype="btrfs",mountpoint="/nix/persist"}'
                      values: "5368709120+0x20"
                    - series: 'node_filesystem_size_bytes{host="loki",job="node-agent",device="/dev/vda3",fstype="btrfs",mountpoint="/nix/persist"}'
                      values: "68719476736+0x20"
                    - series: 'node_filesystem_avail_bytes{host="loki",job="node-agent",device="tmpfs",fstype="tmpfs",mountpoint="/"}'
                      values: "0+0x20"
                    - series: 'node_filesystem_size_bytes{host="loki",job="node-agent",device="tmpfs",fstype="tmpfs",mountpoint="/"}'
                      values: "4294967296+0x20"
                  alert_rule_test:
                    - eval_time: 16m
                      groupname: fleet-storage
                      alertname: HostFilesystemLow
                      exp_alerts:
                        - exp_labels:
                            device: /dev/vda3
                            fstype: btrfs
                            host: loki
                            job: node-agent
                            mountpoint: /nix/persist
                            severity: warning
                          exp_annotations:
                            summary: Low free space on loki:/nix/persist
                            description: Physical free space is below 10%; check snapshot retention and measured data growth.
                    - eval_time: 16m
                      groupname: fleet-storage
                      alertname: HostFilesystemCritical
                      exp_alerts: []
                - name: fleet storage critical
                  interval: 1m
                  input_series:
                    - series: 'node_filesystem_avail_bytes{host="argus",job="node-agent",device="/dev/sda1",fstype="ext4",mountpoint="/"}'
                      values: "2147483648+0x20"
                    - series: 'node_filesystem_size_bytes{host="argus",job="node-agent",device="/dev/sda1",fstype="ext4",mountpoint="/"}'
                      values: "68719476736+0x20"
                  alert_rule_test:
                    - eval_time: 6m
                      groupname: fleet-storage
                      alertname: HostFilesystemCritical
                      exp_alerts:
                        - exp_labels:
                            device: /dev/sda1
                            fstype: ext4
                            host: argus
                            job: node-agent
                            mountpoint: /
                            severity: critical
                          exp_annotations:
                            summary: Critically low free space on argus:/
                            description: Physical free space is below 5%; act before writes start failing.
                - name: fleet storage fill trend
                  interval: 1m
                  input_series:
                    - series: 'node_filesystem_avail_bytes{host="loki",job="node-agent",device="/dev/vda3",fstype="btrfs",mountpoint="/nix/persist"}'
                      values: "17179869184-10485760x420"
                    - series: 'node_filesystem_size_bytes{host="loki",job="node-agent",device="/dev/vda3",fstype="btrfs",mountpoint="/nix/persist"}'
                      values: "68719476736+0x420"
                  alert_rule_test:
                    - eval_time: 90m
                      groupname: fleet-storage
                      alertname: HostFilesystemFillingUp
                      exp_alerts: []
                    - eval_time: 6h
                      groupname: fleet-storage
                      alertname: HostFilesystemFillingUp
                      exp_alerts:
                        - exp_labels:
                            device: /dev/vda3
                            fstype: btrfs
                            host: loki
                            job: node-agent
                            mountpoint: /nix/persist
                            severity: warning
                          exp_annotations:
                            summary: loki:/nix/persist predicted full within a day
                            description: Physical free space is under 25% and its 6-hour trend crosses zero within 24 hours.
                - name: stale alert overlaps absence alert
                  interval: 30s
                  input_series:
                    - series: 'node_time_seconds{host="talos",job="node-agent"}'
                      values: "0 _x20"
                    - series: 'node_time_seconds{host="argus",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="mneme",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="mimir",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="horos",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="hermes",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="charon",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="loki",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="hephaestus",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="bifrost",job="node-agent"}'
                      values: "0+30x20"
                    - series: 'node_time_seconds{host="portunus",job="node-agent"}'
                      values: "0+30x20"
                  alert_rule_test:
                    - eval_time: 6m30s
                      groupname: argus-self
                      alertname: TelemetryHostStale
                      exp_alerts:
                        - exp_labels:
                            host: talos
                            severity: critical
                          exp_annotations:
                            summary: Telemetry from talos is stale
                            description: Check vmagent queue and network path from the host to Argus.
                    - eval_time: 6m30s
                      groupname: argus-self
                      alertname: TelemetryHostAbsent
                      exp_alerts:
                        - exp_labels:
                            host: talos
                            job: node-agent
                            severity: critical
                          exp_annotations:
                            summary: No telemetry received from talos
                            description: Check vmagent, its queue, and network path from talos to Argus.
            '';
          in
            pkgs.runCommand "observability-rules-check" {nativeBuildInputs = [vmalert alertmanager pkgs.envsubst pkgs.jq];} ''
              vmalert -rule=${metricsRules} -dryRun
              vmalert -rule=${logsRules} -rule.defaultRuleType=vlogs -dryRun
              vmalert-tool unittest --files=${metricsRulesTest}
              grep -Fq ObservabilityNotificationTestServiceStopped ${metricsRules}
              test ${lib.escapeShellArg (lib.boolToString notificationTest.serviceConfig.RemainAfterExit)} = true
              UPTIME_KUMA_PUSH_URL=https://uptime.dysthesis.com/api/push/test \
                NTFY_ALERTMANAGER_TOKEN=test \
                envsubst -i ${alertmanagerConfig} -o alertmanager-substituted.json
              amtool check-config alertmanager-substituted.json
              jq -e '
                (.route.routes[] | select(.receiver == "dead-man")) as $deadman
                | $deadman.group_wait == "0s"
                  and $deadman.group_interval == "15s"
                  and $deadman.repeat_interval == "30s"
                  and ([.receivers[] | select(.name == "dead-man")
                    | .webhook_configs[]
                    | select(.send_resolved == false and .url == "$UPTIME_KUMA_PUSH_URL")]
                    | length) == 1
                  and ([.receivers[] | select(.name == "warnings" or .name == "critical")
                    | .webhook_configs[]
                    | select(.send_resolved == true and .http_config.authorization.credentials == "$NTFY_ALERTMANAGER_TOKEN")]
                    | length) == 2
              ' ${alertmanagerConfig}
              touch $out
            '';

          observability-ingress = let
            argus = nixosConfigurations.argus.config;
            caddy = argus.services.caddy.package;
            writers = argus.laplace.services.observability.ingress.writers;
            writerNames = builtins.attrNames writers;
            metricsDials = map (name: "127.0.0.1:${toString writers.${name}.metricsPort}") writerNames;
            journalDials = map (_: "127.0.0.1:9428") writerNames;
            ingressVmagents = map (name: argus.systemd.services."vmagent-ingress-${name}".serviceConfig.ExecStart) writerNames;
          in
            pkgs.runCommand "observability-ingress-check" {nativeBuildInputs = [caddy pkgs.jq];} ''
              caddy adapt --adapter caddyfile --config ${argus.services.caddy.configFile} >caddy.json
              jq -e \
                --argjson metricsDials ${lib.escapeShellArg (builtins.toJSON metricsDials)} \
                --argjson journalDials ${lib.escapeShellArg (builtins.toJSON journalDials)} \
                '
                [.apps.http.servers[] | select(.listen == [":8443"])] as $metrics
                | [.apps.http.servers[] | select(.listen == [":8444"])] as $journals
                | ($metrics | length) == 1 and ($journals | length) == 1
                  and $metrics[0].protocols == ["h1"] and $journals[0].protocols == ["h1"]
                  and ([ $metrics[0] | .. | objects | .dial? // empty ] | sort) == ($metricsDials | sort)
                  and ([ $journals[0] | .. | objects | .dial? // empty ] | sort) == ($journalDials | sort)
                  and ([ $metrics[0] | .. | objects | .status_code? // empty ] | index(404)) != null
                  and ([ $journals[0] | .. | objects | .status_code? // empty ] | index(404)) != null
                  and ([ $metrics[0].tls_connection_policies[]?.client_authentication? | select(.) ] | length) == 1
                  and ([ $journals[0].tls_connection_policies[]?.client_authentication? | select(.) ] | length) == 1
              ' caddy.json
              ${lib.concatMapStringsSep "\n" (command: "${command} -dryRun") ingressVmagents}
              touch $out
            '';
        };
    }
    // {
      overlays = {
        linux-hardened = import ./nix/overlays/linux-hardened.nix;
        default = self.overlays.linux-hardened;
      };

      inherit nixosConfigurations;

      colmena = import ./nix/deploy {
        inherit self inputs lib;
        inherit (hosts) nodeModules;
      };

      colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Channel revisions have Hydra substitutes; raw master may not.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    read = {
      url = "github:dysthesis/read";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # This fork needs the Go toolchain from its own nixpkgs pin.
    headscale.url = "github:dysthesis/headscale?ref=feat/wg-only-peers";

    poincare = {
      url = "github:dysthesis/poincare";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    serena = {
      url = "github:oraios/serena";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dwl = {
      url = "github:dysthesis/dwl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gungnir fails under Determinate Nix, but no host enables Xorg.
    gungnir = {
      url = "github:dysthesis/gungnir";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mandelbrot = {
      url = "github:dysthesis/mandelbrot";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    daedalus = {
      url = "github:dysthesis/daedalus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Not in nixpkgs.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oh-my-pi = {
      url = "github:can1357/oh-my-pi/v18.12.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    status = {
      url = "github:dysthesis/status";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    iosevka-cadmus = {
      url = "github:dysthesis/iosevka-cadmus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    colmena.url = "github:nix-community/colmena";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };
}
