{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
in {
  options.laplace.bootloader = mkEnumOption {
    elems = ["systemd-boot"];
    description = "Which bootloader to use";
  };
  imports = [
    ./systemd-boot
  ];
}
