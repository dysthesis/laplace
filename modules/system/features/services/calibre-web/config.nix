{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.calibre-web;
in {
  config = mkIf cfg.enable {
    # Calibre-Web
    services.calibre-web = {
      enable = true;
      listen = {
        ip = "127.0.0.1";
        inherit (cfg) port;
      };

      options = {
        calibreLibrary = cfg.libraryPath;
        enableBookUploading = true;
        enableBookConversion = true;
      };
    };
  };
}
