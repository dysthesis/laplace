{lib}: {
  port = lib.mkOption {
    type = lib.types.port;
    default = 80;
  };
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "0.0.0.0";
  };
  upstreamDNS = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Ordered resolver list, including site-specific forwarding rules.";
  };
  exceptionClientAddress = lib.mkOption {
    type = lib.types.str;
    description = "Tailnet identity address for the existing per-client allow rule.";
  };
}
