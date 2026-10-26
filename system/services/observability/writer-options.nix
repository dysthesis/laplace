{lib}: let
  inherit (lib) mkOption types;
in {
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
}
