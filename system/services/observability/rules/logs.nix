{
  groups = [
    {
      name = "critical-logs";
      type = "vlogs";
      interval = "1m";
      rules = [
        {
          alert = "CriticalLogDetected";
          expr = ''PRIORITY:in(0,1,2) | stats by (source) count() as critical_logs | filter critical_logs:>0'';
          labels.severity = "critical";
          annotations = {
            summary = "Critical-priority logs from {{ $labels.source }}";
            description = "Open VictoriaLogs for source={{ $labels.source }} and inspect the last minute before acknowledging.";
          };
        }
      ];
    }
  ];
}
