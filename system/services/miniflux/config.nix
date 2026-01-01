{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.miniflux.enable;
  inherit (lib)
    mkIf
    ;
in {
  config = mkIf cfg {
    # Tell sops-nix that this should be found in the default sops file.
    sops.secrets.miniflux_admin = {};

    services.miniflux = {
      enable = true;
      config = {
        LISTEN_ADDR = "localhost:8085";
        CLEANUP_FREQUENCY = "168";
      };
      adminCredentialsFile = config.sops.secrets.miniflux_admin.path;
    };

    virtualisation.oci-containers.containers."full-text-rss" = {
      autoStart = true;
      image = "heussd/fivefilters-full-text-rss:latest";
      ports = ["7756:80"];
    };

    laplace.docker.enable = true;

    users = {
      groups.miniflux = {};
      users.miniflux = {
        isSystemUser = true;
        group = "miniflux";
      };
    };
  };
}
