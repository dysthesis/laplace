{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.wallabag;
in {
  config = let
    inherit
      (cfg)
      subdomain
      dataPath
      port
      ;
  in
    mkIf cfg.enable {
      virtualisation.oci-containers.containers.wallabag = {
        autoStart = true;
        image = "wallabag/wallabag:latest";
        ports = ["${toString port}:80"];
        volumes = [
          "${dataPath}/data:/var/www/wallabag/data"
          "${dataPath}/images:/var/www/wallabag/web/assets/images"
        ];
        environment = {
          SYMFONY__ENV__DOMAIN_NAME = "http://${subdomain}.home";
          SYMFONY__ENV__FOSUSER_CONFIRMATION = "false";
          SYMFONY__ENV__SERVER_NAME = "Wallabag";
        };
        extraOptions = ["--pull=always"];
      };
    };
}
