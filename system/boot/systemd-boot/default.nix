{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
    ;
  cfg = config.laplace.bootloader;
in
{
  config = mkIf (cfg == "systemd-boot") {
    boot = {
      initrd.systemd.enable = true;
      loader = {
        timeout = 5;
        efi.canTouchEfiVariables = true;

        grub.enable = false;

        systemd-boot = {
          # We might want to set this to false for Lanzaboote
          enable = mkDefault true;
          editor = false;
          consoleMode = "max";
        };
      };
    };
  };
}
