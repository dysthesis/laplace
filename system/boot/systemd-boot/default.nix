{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkDefault
    ;
  cfg = config.laplace.bootloader;
in {
  config = mkIf (cfg == "systemd-boot") {
    boot = {
      initrd.systemd.enable = true;
      loader = {
        timeout = mkDefault 5;
        efi.canTouchEfiVariables = true;

        grub.enable = false;

        systemd-boot = {
          # mkDefault so the secure-boot module can force this off for lanzaboote
          enable = mkDefault true;
          editor = false;
          consoleMode = "max";
        };
      };
    };
  };
}
