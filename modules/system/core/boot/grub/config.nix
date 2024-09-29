{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.laplace.bootloader;
in {
  config = mkIf (cfg == "grub") {
    boot = {
      initrd.systemd.enable = true;
      loader = {
        timeout = 5;
        efi.canTouchEfiVariables = true;

        grub = {
          enable = false;
          efiSupport = true;
          efiInstallAsRemovable = true;
        };

        systemd-boot.enable = mkForce true;
      };
    };
  };
}
