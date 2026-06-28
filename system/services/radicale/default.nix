{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.radicale;
  inherit (lib) mkEnableOption mkIf mkOption types;
  port = 5232;
in {
  options.laplace.services.radicale = {
    enable = mkEnableOption "Radicale CalDAV/CardDAV server";

    port = mkOption {
      type = types.port;
      default = port;
      description = "Loopback port for Radicale; the node-local Caddy proxies to this.";
    };
  };

  config = mkIf cfg.enable {
    mnemosyne.dirs = ["/var/lib/radicale"];

    services.radicale = {
      enable = true;
      settings = {
        server.hosts = ["127.0.0.1:${toString cfg.port}"];
        storage.filesystem_folder = "/var/lib/radicale/collections";
        # No Radicale credential secret exists yet. Tailnet + Headscale ACL + Caddy
        # gate network reach; add htpasswd auth before sharing beyond owner devices.
        auth.type = "none";
      };
    };
  };
}
