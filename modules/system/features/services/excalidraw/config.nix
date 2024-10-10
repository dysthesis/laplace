{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.excalidraw;
in {
  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.excalidraw = {
      autoStart = true;
      image = "excalidraw/excalidraw:latest";
      environment = {
        TZ = "Australia/Sydney";
      };
      ports = [
        "3030:80"
      ];
    };
  };
}
