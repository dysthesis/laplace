{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.calibre-web;
in {
  config = mkIf cfg.enable {
    services = {
      calibre-web = {
        enable = true;
        options = {
          enableBookUploading = true;
          enableBookConversion = true;
          calibreLibrary = cfg.libraryPath;
        };
      };

      calibre-server = {
        enable = true;
        libraries = [cfg.libraryPath];
      };
    };
    # TODO: upstream that
    systemd.services.calibre-server.serviceConfig.ExecStart = lib.mkForce "${pkgs.calibre}/bin/calibre-server ${cfg.libraryPath} --enable-auth";
  };
}
