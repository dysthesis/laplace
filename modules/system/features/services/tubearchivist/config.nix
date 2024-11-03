{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.tubearchivist;
in {
  config = mkIf cfg.enable {
    sops.secrets.tubearchivist = {};
    virtualisation.oci-containers.containers = {
      tubearchivist = let
        inherit
          (cfg)
          youtubePath
          cachePath
          ;
      in {
        imageFile = pkgs.dockerTools.pullImage {
          imageName = "bbilly1/tubearchivist";
          imageDigest = "sha256:589dbfcd7ba36e608294cc586b80820a6651eaa80cc22eba871aa9980cdc85fd";
          sha256 = "sha256-kREVFRdayfeSgVaxaBKBRmUTXdkFA2ddI06MTBlaChY=";
        };
        image = "bbilly1/tubearchivist:v0.4.5";

        ports = ["8000:8000"];

        volumes = [
          "${youtubePath}:/youtube"
          "${cachePath}:/cache"
        ];

        environment = {
          TA_HOST = cfg.address;
          TZ = "Australia/Sydney";
          REDIS_HOST = "archivist-redis";
        };

        environmentFiles = [config.sops.secrets.tubearchivist.path];

        extraOptions = [
          "--network=tubearchivist-br"
        ];
        autoStart = true;
      };
      archivist-redis = {
        imageFile = pkgs.dockerTools.pullImage {
          imageName = "redis/redis-stack-server";
          imageDigest = "sha256:7df84d4e2f0e1d3d5d85f6ee96f1a42effe851527a72170933f8822341f83b74";
          sha256 = "sha256-yeT9lhX1ArzVUyRG50a01PJn8Kifv7HPORzEf7DtT5c=";
        };
        image = "redis/redis-stack-server:latest";

        ports = ["6379:6379"];

        volumes = [
          "es:/usr/share/elasticsearch/data"
        ];

        extraOptions = [
          "--network=tubearchivist-br"
        ];

        autoStart = true;
      };
    };

    systemd.services.init-tubearchivist-bridge = {
      description = "Create the network bridge for tubearchivist.";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig.Type = "oneshot";
      script = let
        dockercli = "${config.virtualisation.podman.package}/bin/podman";
      in ''
        # Put a true at the end to prevent getting non-zero return code, which will
        # crash the whole service.
        check=$(${dockercli} network ls | grep "tubearchivist-br" || true)
        if [ -z "$check" ]; then
          ${dockercli} network create tubearchivist-br
        else
          echo "tubearchivist-br already exists in docker"
        fi
      '';
    };
  };
}
