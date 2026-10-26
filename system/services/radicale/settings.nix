{lib}: {
  port = lib.mkOption {
    type = lib.types.port;
    default = 5232;
    description = "Loopback port for Radicale; the node-local Caddy proxies to this.";
  };
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
  };
}
