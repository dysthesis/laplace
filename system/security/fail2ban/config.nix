{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.security.fail2ban;
in {
  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      ignoreIP = [
        "192.168.1.0/24"
      ];
      extraPackages = [pkgs.ipset];
      banaction = "iptables-ipset-proto6-allports";
    };
  };
}
