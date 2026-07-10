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
        "10.0.20.0/24" # VLAN20 (services/desktops) — LAN deploy/admin
        "10.0.40.0/24" # VLAN40 (edge/headscale)
        # tailnet (100.64.0.0/10) intentionally NOT whitelisted: a popped tailnet
        # leaf (loki) brute-forcing peers should be throttled, not exempt. The flip
        # already drops tailnet :22 to servers; this is the layer-3 backstop.
      ];
      extraPackages = [pkgs.ipset]; # ipset is only used by the iptables-family branch below
      # iptables-family banactions silently fail with exit 127 on pure-nft hosts
      # (`iptables` is absent from fail2ban's PATH) → the ban never installs and
      # throttling is cosmetic. Match the action to the firewall backend, the same
      # gate the proxmox profile / beszel use for the nftables-vs-iptables trap.
      banaction =
        if config.networking.nftables.enable
        then "nftables-multiport"
        else "iptables-ipset-proto6-allports";
    };
  };
}
