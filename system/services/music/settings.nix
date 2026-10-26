{lib}: {
  domain = lib.mkOption {type = lib.types.str;};
  sopsFile = lib.mkOption {type = lib.types.path;};
}
