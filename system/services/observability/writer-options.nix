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
}
