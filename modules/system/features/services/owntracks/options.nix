{lib, ...}: let
  inherit (lib) mkOption mkEnableOption;
  inherit (lib.types) str port;
in {
  options.laplace.features.services.owntracks = {
    enable = mkEnableOption "Whether or not to enable the Owntracks location tracker";
    host = mkOption {
      type = str;
      default = "127.0.0.1";
    };

    port = mkOption {
      type = port;
      default = 9712;
    };

    subdomain = mkOption {
      type = str;
      default = "track";
    };
  };
}
