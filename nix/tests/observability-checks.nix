{
  pkgs,
  lib,
  inputs,
  self,
  serviceFixtures,
}: {
  observability-dashboard-lifecycle = import ./observability-dashboard-lifecycle.nix {
    inherit pkgs lib inputs self;
  };

  observability-dashboards = let
    dashboards = serviceFixtures.observability.system.build.observabilityDashboards;
    vmalert = serviceFixtures.observability.services.vmalert.package;
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
    argus = serviceFixtures.observability;
    vmalert = argus.services.vmalert.package;
    metricsRules = argus.environment.etc."vmalert-metrics/rules.yml".source;
    logsRules = argus.environment.etc."vmalert-logs/rules.yml".source;
    alertmanagerConfig = pkgs.writeText "alertmanager.json" (builtins.toJSON argus.services.prometheus.alertmanager.configuration);
    alertmanager = argus.services.prometheus.alertmanager.package;
    notificationTest = argus.systemd.services.observability-notification-test;
    # vmalert-tool v1.154.0 starts at 2000-01-01T00:00:00Z, not Unix epoch 0.
    testStartSeconds = "946684800";
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
        - name: stale and absent telemetry recovers without alerting healthy hosts
          interval: 30s
          input_series:
            - series: 'node_time_seconds{host="talos",job="node-agent"}'
              values: "${testStartSeconds} _x13 946685220+30x6"
            - series: 'node_time_seconds{host="argus",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="mneme",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="mimir",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="horos",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="hermes",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="charon",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="loki",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="hephaestus",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="bifrost",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
            - series: 'node_time_seconds{host="portunus",job="node-agent"}'
              values: "${testStartSeconds}+30x20"
          alert_rule_test:
            - eval_time: 4m
              groupname: argus-self
              alertname: TelemetryHostStale
              exp_alerts: []
            - eval_time: 5m
              groupname: argus-self
              alertname: TelemetryHostAbsent
              exp_alerts: []
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
            - eval_time: 7m30s
              groupname: argus-self
              alertname: TelemetryHostStale
              exp_alerts: []
            - eval_time: 7m30s
              groupname: argus-self
              alertname: TelemetryHostAbsent
              exp_alerts: []
    '';
  in
    pkgs.runCommand "observability-rules-check" {nativeBuildInputs = [vmalert alertmanager pkgs.envsubst pkgs.jq];} ''
      vmalert -rule=${metricsRules} -dryRun
      vmalert -rule=${logsRules} -rule.defaultRuleType=vlogs -dryRun
      vmalert-tool unittest --files=${metricsRulesTest}
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
    argus = serviceFixtures.observability;
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
}
