{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.owntracks;
in {
  config = mkIf cfg.enable {
    sops.secrets."hashedPasswords/mosquitto" = {};

    networking.firewall.allowedTCPPorts = [1883 8883];
    services.mosquitto = {
      enable = true;
      settings.max_keepalive = 300;
      listeners = [
        {
          port = 1883;
          omitPasswordAuth = true;
          users = {};
          settings = {
            allow_anonymous = true;
          };
          acl = ["topic readwrite #"];
        }
        {
          port = 8883;
          omitPasswordAuth = true;
          users = {};
          settings = {
            protocol = "websockets";
            allow_anonymous = true;
          };
          acl = ["topic readwrite #" "pattern readwrite #"];
        }
      ];
    };
  };
}
