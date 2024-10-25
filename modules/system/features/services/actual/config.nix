{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.actual;
in {
  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.actual = {
      image = "ghcr.io/actualbudget/actual-server:24.8.0@sha256:cbdc8d5bd612593d552e8f2e5f05fa959040a924ded6a56d123c51ca6c571337";
      ports = ["${cfg.address}:${toString cfg.port}:5006"];
      volumes = [
        "${cfg.dataDir}:/data"
      ];
    };

    systemd.services.docker-actual.after = ["var-lib-actual.mount"];
  };
}
