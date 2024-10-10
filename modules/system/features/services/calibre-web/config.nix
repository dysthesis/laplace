{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.laplace.features.services.calibre-web;
in {
  config = mkIf cfg.enable {
    services = {
      calibre-web = {
        enable = true;
        listen.port = 8084;
        options = {
          enableBookUploading = true;
          enableBookConversion = true;
          calibreLibrary = "/usr/share/calibre-web";
        };
      };

      calibre-server = {
        enable = true;
        libraries = [config.services.calibre-web.options.calibreLibrary];
      };
    };
    # TODO: upstream that
    systemd.services.calibre-server.serviceConfig.ExecStart = lib.mkForce "${pkgs.calibre}/bin/calibre-server ${config.services.calibre-web.options.calibreLibrary} --enable-auth";
  };
}
