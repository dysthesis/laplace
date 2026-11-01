{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.security.secure-boot.enable;
in {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  options.laplace.security.secure-boot.enable =
    mkEnableOption "Whether or not to enable secure boot.";

  config = mkIf cfg {
    mnemosyne.dirs = ["/var/lib/sbctl"];

    environment.systemPackages = [
      pkgs.unstable.sbctl
    ];

    boot = {
      # lanzaboote replaces systemd-boot. Override the default to disable the module.
      loader.systemd-boot.enable = lib.mkForce false;
      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    };
  };
}
