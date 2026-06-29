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

    sops.secrets.radicale_htpasswd = {
      owner = "radicale";
      group = "radicale";
      mode = "0400";
      restartUnits = ["radicale.service"];
    };

    services.radicale = {
      enable = true;
      settings = {
        server.hosts = ["127.0.0.1:${toString cfg.port}"];
        storage.filesystem_folder = "/var/lib/radicale/collections";
        auth = {
          type = "htpasswd";
          htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
          htpasswd_encryption = "bcrypt";
        };
      };
    };
  };
}
