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
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          users.root = {
            acl = ["readwrite #"];
            hashedPasswordFile = config.sops.secrets."hashedPasswords/mosquitto".path;
          };
        }
      ];
    };

    # default mosquitto port. change as required
    networking.firewall = {allowedTCPPorts = [1883];};
  };
}
