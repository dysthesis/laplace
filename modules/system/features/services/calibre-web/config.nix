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
    virtualisation.oci-containers.containers.calibre-web = let
      inherit (cfg) port;
    in {
      image = "ghcr.io/linuxserver/calibre-web";
      ports = ["${toString port}:8083"];
      volumes = [
        "${cfg.configPath}:/config"
        "${cfg.libraryPath}:/books"
      ];
      extraOptions = [
        "--runtime=${pkgs.gvisor}/bin/runsc"
      ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Australia/Sydney";
      };
    };
  };
}
