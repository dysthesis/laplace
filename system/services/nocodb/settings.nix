{lib}: {
  domain = lib.mkOption {
    type = lib.types.str;
    description = "NocoDB site hostname; DNS publication does not create a proxy route.";
  };
  port = lib.mkOption {
    type = lib.types.port;
    default = 8088;
  };
  sopsFile = lib.mkOption {
    type = lib.types.path;
    description = "Encrypted source of the existing NocoDB database, JWT and connection keys.";
  };
}
