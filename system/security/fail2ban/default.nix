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
        "192.168.1.0/24"
      ];
      extraPackages = [pkgs.ipset];
      banaction = "iptables-ipset-proto6-allports";
    };
  };
}
