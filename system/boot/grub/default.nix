{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    ;
  cfg = config.laplace.bootloader;
in
{
  config = mkIf (cfg == "grub") {
    boot = {
      loader = {
        timeout = 5;
        efi.canTouchEfiVariables = true;

        grub = {
          enable = true;
        };

        systemd-boot.enable = mkForce false;
      };
    };
  };
}
