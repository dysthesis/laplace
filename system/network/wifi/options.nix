{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.network.wifi.enable = mkEnableOption "Whether or not to enable Wi-Fi support.";
}
