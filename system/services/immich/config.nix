{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.immich;
in {
  config = mkIf cfg.enable {
    # Bind to the trusted tailnet interface without opening a firewall port.
    assertions = [
      {
        assertion = config.laplace.services.tailscale.enable;
        message = "laplace.services.immich binds to the tailnet; enable laplace.services.tailscale on this host.";
      }
    ];

    # ML models exceed small tmpfs roots, so keep the cache on disk.
    mnemosyne.dirs = [
      cfg.mediaLocation
      config.services.postgresql.dataDir
      "/var/cache/immich"
    ];

    # Pin UID and GID so persisted media ownership survives root resets.
    users.users.immich.uid = 997;
    users.groups.immich.gid = 997;

    services.immich = {
      enable = true;
      package = pkgs.unstable.immich;
      inherit (cfg) host mediaLocation port;
      openFirewall = false;
      # Local PostgreSQL uses peer auth; leave app settings mutable in the UI.
    };
  };
}
