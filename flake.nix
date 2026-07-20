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
      devShells = pkgs: {default = import ./nix/shell pkgs;};

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
          # Each selected compositor/session module contributes its own
          # validation via laplace.display.checkCommands, so this check
          # follows compositor swaps without edits here.
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
            assert server.reloadIfChanged == false;
            assert server.restartIfChanged == false;
              pkgs.runCommand "minecraft-config-staging-check" {} ''
                grep -Fqx 'systemctl try-restart "$unit"' ${restart}
                touch $out
              '';

          # Build-time half of PLAN §5 layer 4: gate the SSOT-rendered Headscale
          # policy and rendered service config against the same headscale binary
          # bifrost runs. configtest needs writable state paths, so the sandbox
          # copies the rendered config and rewrites only /var/lib + /run paths to
          # $TMPDIR. toJSON guarantees well-formed HuJSON, but only the control
          # plane catches semantic faults (undefined tag/alias, empty group). The
          # eval-time checkTailnet invariants
          # (system/tailnet/default.nix) already fire fleet-wide; this is the
          # remaining check the build sandbox CAN run (no network/db needed).
          # Runtime tag reconcile (gotcha 4) is `just tailnet-reconcile`, not a
          # check here — the sandbox has no network.
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

      # Push-deploy hive for the Proxmox guests: `colmena apply --on @proxmox`
      # (or `just deploy`). See nix/deploy.
      colmena = import ./nix/deploy {
        inherit self inputs lib;
        inherit (hosts) nodeModules overlays;
      };
    };

  inputs = {
    # TODO: See if switching to unstable fixes
    # https://github.com/NixOS/nixpkgs/issues/222181
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";

    # Supposedly faster Nix.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    read = {
      url = "github:dysthesis/read";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Keep fork's own nixpkgs pin: it carries the Go toolchain revision used by
    # this headscale fork.
    headscale.url = "github:dysthesis/headscale?ref=feat/wg-only-peers";

    # Neovim flake
    poincare = {
      url = "github:dysthesis/poincare";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dwl = {
      url = "github:dysthesis/dwl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Suckless suite (st, dmenu, xsecurelock) for the xorg session.
    # NOTE: gungnir's `packages` output currently fails to evaluate under
    # Determinate Nix. The xorg path in system/users/demiurge is lazy and
    # unused (no host enables it), so this stays dormant until gungnir is
    # fixed upstream; restoring the input only resolves the dangling ref.
    gungnir = {
      url = "github:dysthesis/gungnir";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # XMonad flake
    mandelbrot = {
      url = "github:dysthesis/mandelbrot";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # tmux flake
    daedalus = {
      url = "github:dysthesis/daedalus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For some reason, this browser isn't in nixpkgs
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware QOL stuff for the Framework laptop
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Sandboxing utility
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Needed for comma
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

    # Hister needs Go 1.26, therefore nixpkgs should follow nixpkgs-unstable
    # (26.05 pin is too old), reusing the existing unstable input rather than a
    # third nixpkgs instance.
    hister = {
      url = "github:asciimoo/hister";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Teaching slides
    slides = {
      url = "git+file:///home/demiurge/Documents/University/COMP6841_2026T2?ref=main";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    iosevka-cadmus = {
      url = "github:dysthesis/iosevka-cadmus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
}
