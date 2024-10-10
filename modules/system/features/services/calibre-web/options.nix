{lib, ...}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) path;
in {
  options.laplace.features.services.calibre-web = {
    enable = mkEnableOption "Whether or not to enable the Calibre Web interface";
    libraryPath = mkOption {
      type = path;
      description = "Where the library is stored";
      default = "/usr/share/calibre";
    };
  };
}
