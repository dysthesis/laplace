{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkForce
    ;

  cfg = config.laplace.security.firewall.enable;
in {
  config = mkIf cfg {
    services.opensnitch.enable = true;

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [443 8080];
      allowedUDPPorts = [];
      allowPing = false;
      logReversePathDrops = true;
      logRefusedConnections = false;
      checkReversePath = mkForce false;
    };
  };
}
