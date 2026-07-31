{expectedHosts}: {
  groups = [
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
      # simplification: per-snapshot attribution would require costly qgroups.
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
    {
      # Thresholds from measured baselines: ~450 idle chunks, ~2 ms mean tick. The 2026-07
      # incident hit 60k chunks, p95 tick 30 -> 209 ms. Every `for` outlasts the 05:01 restart.
      name = "minecraft";
      interval = "1m";
      rules = let
        chunks = "sum(minecraft_total_loaded_chunks)";
        players = "sum(minecraft_players_online)";
      in [
        {
          alert = "MinecraftServerDown";
          expr = ''up{job="minecraft"} == 0'';
          for = "10m";
          labels.severity = "critical";
          annotations = {
            summary = "Minecraft exporter on {{ $labels.host }} is unreachable";
            description = "Outlasts the 05:01 restart, so the server itself is likely down; check minecraft-server-retirement-home.service.";
          };
        }
        {
          alert = "MinecraftTPSLow";
          expr = "minecraft_tps < 19";
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = "Minecraft TPS on {{ $labels.host }} below 19";
            description = "The server can no longer keep 20 ticks per second; take a spark profile while it is still degraded.";
          };
        }
        {
          # 50 ms tick budget; half gone precedes visible stutter.
          alert = "MinecraftTickTimeHigh";
          expr = ''minecraft_mspt{type="mean"} > 25'';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = "Minecraft mean tick time on {{ $labels.host }} above 25 ms";
            description = "Half the 50 ms tick budget is gone; profile before players notice.";
          };
        }
        {
          alert = "MinecraftTickTimeCritical";
          expr = ''minecraft_mspt{type="mean"} > 40'';
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "Minecraft mean tick time on {{ $labels.host }} above 40 ms";
            description = "Ticks are about to overrun their 50 ms budget; players will see lag now.";
          };
        }
        {
          alert = "MinecraftLoadedChunksHigh";
          expr = "${chunks} > 12000";
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "Minecraft loaded chunks above 12000";
            description = "Well beyond the ~450 idle and ~4300 busy baselines; heap and tick time degrade past this point.";
          };
        }
        {
          # DH server-generation leak signature: working set grows with nobody online.
          alert = "MinecraftChunkLeak";
          expr = "(${chunks} - sum(min_over_time(minecraft_total_loaded_chunks[3h]))) > 5000 and ${players} == 0";
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "Minecraft chunks growing with no players online";
            description = "Chunks are not being released; check enableServerGeneration and the request-distance settings in DistantHorizons.toml.";
          };
        }
        {
          alert = "MinecraftHeapPressure";
          expr = ''jvm_memory_bytes_used{job="minecraft",area="heap"} / jvm_memory_bytes_max{job="minecraft",area="heap"} > 0.90'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "Minecraft heap above 90% on {{ $labels.host }}";
            description = "GC pressure lengthens ticks; the 8 GiB heap may be undersized for the current chunk load.";
          };
        }
      ];
    }
  ];
}
