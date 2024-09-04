{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.network.bluetooth.enable = mkEnableOption "Whether or not to enable Bluetooth support";
}
