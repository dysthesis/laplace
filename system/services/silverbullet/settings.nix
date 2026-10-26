{lib}: {
  port = lib.mkOption {
    type = lib.types.port;
    default = 8101;
  };
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
  };
}
