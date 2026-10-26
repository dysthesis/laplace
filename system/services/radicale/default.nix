{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.radicale;
  common = import ../personal-common.nix {inherit lib;};
  inherit (lib) mkEnableOption mkIf;
in {
  options.laplace.services.radicale =
    {enable = mkEnableOption "Radicale CalDAV/CardDAV server";}
    // import ./settings.nix {inherit lib;};
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
        server.hosts = [(common.hostPort cfg.listenAddress cfg.port)];
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
