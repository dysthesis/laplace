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

  cfg = config.laplace.security.firewall.enable;
in {
  options.laplace.security.firewall.enable = mkEnableOption "Whether or not to enable firewall";
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
