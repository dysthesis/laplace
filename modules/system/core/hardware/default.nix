{lib, ...}: let
  inherit (lib) mkDefault;
in {
  imports = [
    ./cpu
    ./gpu
  ];
  config.services.fwupd.enable = mkDefault true;
}
