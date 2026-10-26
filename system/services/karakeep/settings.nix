{lib}: {
  domain = lib.mkOption {
    type = lib.types.str;
    example = "read.example.com";
    description = "Public origin hostname for NEXTAUTH_URL.";
  };
  port = lib.mkOption {
    type = lib.types.port;
    default = 3000;
    description = "Loopback HTTP port the web app listens on.";
  };
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
  };
  browserPort = lib.mkOption {
    type = lib.types.port;
    default = 9222;
    description = "Loopback Chromium DevTools port, also exported to colocated consumers.";
  };
  searchPort = lib.mkOption {
    type = lib.types.port;
    default = 7700;
  };
  disableSignups = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Reject new registrations after the initial administrator exists.";
  };
}
