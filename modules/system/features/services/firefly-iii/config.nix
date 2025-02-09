{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.firefly-iii;
in {
  config = mkIf cfg.enable {
    services.firefly-iii = {
      enable = true;
      package = pkgs.firefly-iii;
      settings = {
        APP_KEY_FILE = config.sops.secrets.firefly-key.path;
        DB_CONNECTION = "mysql";
        DB_DATABASE = "firefly";
        DB_HOST = "localhost";
        DB_USERNAME = "firefly-iii";
      };
    };

    sops.secrets.firefly-key.owner = "firefly-iii";

    services.mysql = let
      inherit (config.services.firefly-iii) settings;
    in {
      ensureDatabases = [settings.DB_DATABASE];
      ensureUsers = [
        {
          name = settings.DB_USERNAME;
          ensurePermissions = {"${settings.DB_DATABASE}.*" = "ALL PRIVILEGES";};
        }
      ];
    };
  };
}
