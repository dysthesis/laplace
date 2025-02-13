{ config, ... }:
let
  cfg = config.laplace.network.bluetooth.enable;
in
{
  config = {
    hardware.bluetooth.enable = cfg;
  };
}
