{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.network.vpn.enable = mkEnableOption "Whether or not to enable VPN with Mullvad";
}
