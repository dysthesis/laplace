{lib}: {
  port = lib.mkOption {
    type = lib.types.port;
    default = 3456;
  };
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
  };
}
