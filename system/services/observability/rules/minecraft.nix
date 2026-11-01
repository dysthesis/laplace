{host}: {
  # Thresholds use measured baselines: about 450 idle chunks and a 2 ms mean tick.
  # All `for` durations are longer than the 05:01 restart.
  name = "minecraft";
  interval = "1m";
  rules = let
    chunks = ''sum(minecraft_total_loaded_chunks{host="${host}"})'';
    players = ''sum(minecraft_players_online{host="${host}"})'';
  in [
    {
      alert = "MinecraftServerDown";
      expr = ''up{job="minecraft",host="${host}"} == 0'';
      for = "10m";
      labels.severity = "critical";
      annotations = {
        summary = "Minecraft exporter on {{ $labels.host }} is unreachable";
        description = "Outlasts the 05:01 restart, so the server itself is likely down; check minecraft-server-retirement-home.service.";
      };
    }
    {
      alert = "MinecraftTPSLow";
      expr = ''minecraft_tps{host="${host}"} < 19'';
      for = "10m";
      labels.severity = "warning";
      annotations = {
        summary = "Minecraft TPS on {{ $labels.host }} below 19";
        description = "The server can no longer keep 20 ticks per second; take a spark profile while it is still degraded.";
      };
    }
    {
      # Set the warning at half the 50 ms tick budget, before players see stutter.
      alert = "MinecraftTickTimeHigh";
      expr = ''minecraft_mspt{host="${host}",type="mean"} > 25'';
      for = "10m";
      labels.severity = "warning";
      annotations = {
        summary = "Minecraft mean tick time on {{ $labels.host }} above 25 ms";
        description = "Half the 50 ms tick budget is gone; profile before players notice.";
      };
    }
    {
      alert = "MinecraftTickTimeCritical";
      expr = ''minecraft_mspt{host="${host}",type="mean"} > 40'';
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
      # Detect Distant Horizons server-generation leaks when no players are online.
      alert = "MinecraftChunkLeak";
      expr = ''(${chunks} - sum(min_over_time(minecraft_total_loaded_chunks{host="${host}"}[3h]))) > 5000 and ${players} == 0'';
      for = "30m";
      labels.severity = "warning";
      annotations = {
        summary = "Minecraft chunks growing with no players online";
        description = "Chunks are not being released; check enableServerGeneration and the request-distance settings in DistantHorizons.toml.";
      };
    }
    {
      alert = "MinecraftHeapPressure";
      expr = ''jvm_memory_bytes_used{job="minecraft",host="${host}",area="heap"} / jvm_memory_bytes_max{job="minecraft",host="${host}",area="heap"} > 0.90'';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "Minecraft heap above 90% on {{ $labels.host }}";
        description = "GC pressure lengthens ticks; the 8 GiB heap may be undersized for the current chunk load.";
      };
    }
  ];
}
