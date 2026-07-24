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
        "10.0.20.0/24" # VLAN20 LAN deploy/admin
        "10.0.40.0/24" # VLAN40 (edge/headscale)
        # Do not exempt tailnet peers; a compromised leaf must still be throttled.
      ];
      extraPackages = [pkgs.ipset]; # ipset is only used by the iptables-family branch below
      # Match banactions to the firewall backend; missing iptables makes bans no-ops.
      banaction =
        if config.networking.nftables.enable
        then "nftables-multiport"
        else "iptables-ipset-proto6-allports";
    };
  };
}
