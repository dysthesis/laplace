{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.network.vpn;
in {
  options.laplace.network.vpn.enable = mkEnableOption "Whether or not to enable VPN with Mullvad";
  config = mkIf cfg.enable {
    mnemosyne.dirs = [
      "/etc/mullvad-vpn"
      "/var/cache/mullvad-vpn"
    ];

    sops.secrets.mullvad = {};
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
  };
}
