{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption;
  cfg = config.laplace.network.bluetooth.enable;
in {
  options.laplace.network.bluetooth.enable =
    mkEnableOption "Whether or not to enable Bluetooth support";
  config = {
    hardware.bluetooth.enable = cfg;
  };
}
