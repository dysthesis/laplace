{
  expectedHosts,
  minecraftHost ? null,
}: {
  groups =
    [
      {
        name = "argus-self";
        interval = "30s";
        rules =
          [
            {
              alert = "ArgusScrapeTargetDown";
              expr = ''up{job=~"victoria.*|grafana|alertmanager|vmalert.*|vmagent|node|blackbox.*"} == 0'';
              for = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Argus cannot scrape {{ $labels.job }}";
                description = "Check systemctl status for the named service, then inspect its journal.";
              };
            }
            {
              alert = "TelemetryHostStale";
              expr = ''time() - max by(host) (last_over_time(node_time_seconds{job="node-agent"}[10m])) > 120'';
              for = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Telemetry from {{ $labels.host }} is stale";
                description = "Check vmagent queue and network path from the host to Argus.";
              };
            }
            {
              alert = "ArgusFilesystemLow";
              expr = ''
                (vm_free_disk_space_bytes < 7 * 1024^3 and vm_free_disk_space_bytes >= 13 * 1024^3 / 2)
                or (vl_free_disk_space_bytes < 20 * 1024^3 and vl_free_disk_space_bytes >= 18 * 1024^3)
              '';
              for = "10m";
              labels.severity = "warning";
              annotations = {
                summary = "Low free space on {{ $labels.path }}";
                description = "Free space is below its store-specific warning threshold; check measured growth and retention.";
              };
            }
            {
              alert = "ArgusFilesystemCritical";
              expr = ''vm_free_disk_space_bytes < 13 * 1024^3 / 2 or vl_free_disk_space_bytes < 18 * 1024^3'';
              for = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Critically low free space on {{ $labels.path }}";
                description = "Act before the backend reaches its minimum-free reserve and rejects writes.";
              };
            }
            {
              alert = "SystemdUnitFailed";
              expr = ''node_systemd_unit_state{state="failed"} == 1'';
              for = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "{{ $labels.name }} failed on {{ $labels.host }}";
                description = "Inspect the unit journal in VictoriaLogs or locally with journalctl.";
              };
            }
            {
              alert = "ObservabilityNotificationTestServiceStopped";
              expr = ''node_systemd_unit_state{job="node",name="observability-notification-test.service",state="active"} == 0'';
              for = "1m";
              labels.severity = "warning";
              annotations = {
                summary = "Argus notification test service is stopped";
                description = "Restart observability-notification-test.service after validating notification delivery.";
              };
            }
            {
              alert = "SyntheticProbeFailed";
              expr = ''probe_success == 0'';
              for = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Synthetic probe failed for {{ $labels.instance }}";
                description = "Check the endpoint, DNS, certificate, and Argus network path.";
              };
            }
            {
              alert = "TelemetryPipelineDeadMan";
              expr = "vector(1)";
              labels.severity = "none";
              annotations = {
                summary = "Argus alert pipeline heartbeat";
                description = "Route this alert to an external dead-man receiver before production cutover.";
              };
            }
          ]
          ++ map (host: {
            alert = "TelemetryHostAbsent";
            expr = ''absent_over_time(node_time_seconds{job="node-agent",host="${host}"}[5m])'';
            for = "1m";
            labels = {
              severity = "critical";
              inherit host;
            };
            annotations = {
              summary = "No telemetry received from ${host}";
              description = "Check vmagent, its queue, and network path from ${host} to Argus.";
            };
          })
          expectedHosts;
      }
      {
        # statfs counts shared Btrfs extents once, so alerts track physical free space.
        name = "fleet-storage";
        interval = "1m";
        rules = let
          avail = ''node_filesystem_avail_bytes{fstype=~"btrfs|ext4|vfat|xfs"}'';
          ratio = "${avail} / node_filesystem_size_bytes";
        in [
          {
            alert = "HostFilesystemLow";
            expr = "${ratio} < 0.10";
            for = "15m";
            labels.severity = "warning";
            annotations = {
              summary = "Low free space on {{ $labels.host }}:{{ $labels.mountpoint }}";
              description = "Physical free space is below 10%; check snapshot retention and measured data growth.";
            };
          }
          {
            alert = "HostFilesystemCritical";
            expr = "${ratio} < 0.05";
            for = "5m";
            labels.severity = "critical";
            annotations = {
              summary = "Critically low free space on {{ $labels.host }}:{{ $labels.mountpoint }}";
              description = "Physical free space is below 5%; act before writes start failing.";
            };
          }
          {
            alert = "HostFilesystemFillingUp";
            expr = "(${ratio} < 0.25) and (predict_linear(${avail}[6h], 24 * 3600) < 0)";
            for = "1h";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.host }}:{{ $labels.mountpoint }} predicted full within a day";
              description = "Physical free space is under 25% and its 6-hour trend crosses zero within 24 hours.";
            };
          }
        ];
      }
    ]
    ++ (
      if minecraftHost == null
      then []
      else [(import ./minecraft.nix {host = minecraftHost;})]
    );
}
