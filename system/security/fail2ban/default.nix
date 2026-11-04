{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.security.fail2ban;
in {
  options.laplace.security.fail2ban.enable = mkEnableOption "Whether or not to enable fail2ban";
  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      ignoreIP = [
        "127.0.0.0/8" # loopback
        "10.0.20.0/24" # VLAN20 permits LAN deployment and administration.
        "10.0.40.0/24" # VLAN40 contains the edge and Headscale services.
        # Do not exempt tailnet peers. Rate limits must still apply to compromised nodes.
      ];
      extraPackages = [pkgs.ipset]; # The iptables branch uses ipset.
      # Ban actions fail if their firewall backend is unavailable.
      banaction =
        if config.networking.nftables.enable
        then "nftables-multiport"
        else "iptables-ipset-proto6-allports";
    };
  };
}
