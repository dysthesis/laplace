{lib, ...}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    ;
  inherit
    (lib.types)
    str
    path
    port
    ;
in {
  options.laplace.features.services.actual = {
    enable = mkEnableOption "Whether or not to enable Actual Budget";
    dataDir = mkOption {
      type = path;
      description = "Where to store the data for Actual Budget";
      default = "/var/lib/actual";
    };
    address = lib.mkOption {
      type = str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = port;
      default = 5006;
    };
  };
}
