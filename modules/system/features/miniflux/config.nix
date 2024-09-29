{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.features.miniflux.enable;
  inherit (lib) mkIf;
in {
  config = mkIf cfg {
    # Tell sops-nix that this should be found in the default sops file.
    sops.secrets.miniflux_adminCredentials = {};

    services.miniflux = {
      enable = true;
      config = {
        LISTEN_ADDR = "localhost:8080";
        CLEANUP_FREQUENCY = "168";
      };
      adminCredentialsFile = config.sops.secrets.miniflux_adminCredentials.path;
    };

    users = {
      groups.miniflux = {};
      users.miniflux = {
        isSystemUser = true;
        group = "miniflux";
      };
    };
  };
}
