{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.laplace.security.firewallPolicy.enable;
in {
  options.laplace.security.firewallPolicy.enable = mkEnableOption "Laplace firewall policy";
  config = mkIf cfg {
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [];
      allowedUDPPorts = [];
      allowPing = false;
      logReversePathDrops = true;
      logRefusedConnections = false;
    };
  };
}
