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
        "10.0.20.0/24" # VLAN20 (services/desktops)
        "10.0.40.0/24" # VLAN40 (edge/headscale)
        "100.64.0.0/10" # tailnet (CGNAT range Tailscale/Headscale use)
      ];
      extraPackages = [pkgs.ipset];
      banaction = "iptables-ipset-proto6-allports";
    };
  };
}
