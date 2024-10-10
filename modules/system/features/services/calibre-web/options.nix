{lib, ...}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) path int;
in {
  options.laplace.features.services.calibre-web = {
    enable = mkEnableOption "Whether or not to enable the Calibre Web interface";

    libraryPath = mkOption {
      type = path;
      description = "Where the library is stored";
      default = "/usr/share/calibre";
    };

    configPath = mkOption {
      type = path;
      description = "Where the config is stored";
      default = "/var/lib/calibre-web";
    };

    port = mkOption {
      type = int;
      description = "Which port Calibre should be hosted in";
      default = 8083;
    };
  };
}
