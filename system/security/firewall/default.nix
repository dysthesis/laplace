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
      # No service ports declared here. Port 22 is opened independently by
      # services.openssh.openFirewall; each host/profile opens the ports it
      # actually serves. Desktop-only ports (e.g. zotero) and opensnitch live in
      # the desktop profile, so headless servers using this module no longer
      # inherit a desktop port-set.
      allowedTCPPorts = [];
      allowedUDPPorts = [];
      allowPing = false;
      logReversePathDrops = true;
      logRefusedConnections = false;
      # checkReversePath kept at the NixOS default (strict where the kernel
      # supports it). Tailnet hosts relax it to "loose" in the tailscale module
      # because Tailscale's asymmetric routing trips strict RPF; servers without
      # tailscale keep the stricter anti-spoofing default.
    };
  };
}
