{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.features.services.openbooks.enable;
  inherit (lib) mkIf;
  port = 8105;
in {
  config = mkIf cfg {
    virtualisation.oci-containers.containers.openbooks = {
      autoStart = true;
      image = "docker.io/evanbuss/openbooks:4.5.0";
      cmd = [
        "--name"
        "Babel"
        "--persist"
        "--searchbot"
        "searchook"
        "--tls"
      ];
      ports = ["127.0.0.1:${toString port}:80/tcp"];
    };
  };
}
