{lib}: {
  mediaLocation = lib.mkOption {
    type = lib.types.path;
    default = "/var/lib/immich";
    description = "Directory where Immich stores uploaded media.";
  };
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "0.0.0.0";
    description = "Immich bind address, independent of its cluster placement host; no host-wide firewall port is opened.";
  };
  port = lib.mkOption {
    type = lib.types.port;
    default = 2283;
    description = "Port Immich listens on.";
  };
}
