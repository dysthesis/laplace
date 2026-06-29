{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.taskchampion;
  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  options.laplace.services.taskchampion = {
    enable = mkEnableOption "TaskChampion sync server for Taskwarrior 3";

    port = mkOption {
      type = types.port;
      default = 10222;
      description = "Loopback port for the sync server; the node-local Caddy proxies to this.";
    };
  };

  config = mkIf cfg.enable {
    # stateVersion < 26.05 ⇒ the module runs as a static `taskchampion` user with
    # a plain (non-private) StateDirectory, so persist that, not /var/lib/private.
    mnemosyne.dirs = ["/var/lib/taskchampion-sync-server"];

    services.taskchampion-sync-server = {
      enable = true;
      # Bind loopback: the node's own Caddy fronts TLS and proxies to it, so the
      # sync API never needs to listen past localhost.
      host = "127.0.0.1";
      inherit (cfg) port;
      # Data is end-to-end encrypted with the client's secret, which the server
      # never sees, so an open client allowlist behind the tailnet-only Caddy is
      # fine. simplification: no allowClientIds; upgrade by pinning the client UUID.
    };
  };
}
