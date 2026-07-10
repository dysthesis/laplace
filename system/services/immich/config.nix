{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.immich;
in {
  config = mkIf cfg.enable {
    # Tailnet-only: bind to the tailnet but never add the port to the firewall.
    # laplace.services.tailscale marks tailscale0 as a trusted interface, so
    # tailnet peers reach `host:port` while the default firewall blocks LAN and
    # public traffic.
    assertions = [
      {
        assertion = config.laplace.services.tailscale.enable;
        message = "laplace.services.immich binds to the tailnet; enable laplace.services.tailscale on this host.";
      }
    ];

    # Persist uploaded media and the Postgres cluster across ephemeral-root
    # wipes. The machine-learning model cache (/var/cache/immich) is left
    # unpersisted on purpose.
    # simplification: ML models re-download on first use after a wipe; persist
    # /var/cache/immich too if that latency ever matters.
    mnemosyne.dirs = [
      cfg.mediaLocation
      config.services.postgresql.dataDir
    ];

    services.immich = {
      enable = true;
      inherit (cfg) host mediaLocation port;
      # Exposure is gated by the tailscale-trusted interface, not an open port.
      openFirewall = false;
      # database (createDB), redis, and machine-learning default to on. The DB
      # talks over the local /run/postgresql unix socket, so no secretsFile is
      # required. settings stays null = fully configurable from the web admin UI.
    };
  };
}
