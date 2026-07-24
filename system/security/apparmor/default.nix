{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.security.apparmor.enable;
in {
  options.laplace.security.apparmor.enable = mkEnableOption "Whether or not to enable AppArmor.";
  config = mkIf cfg {
    services.dbus.apparmor = "disabled";

    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = true;
      packages = [pkgs.apparmor-profiles];
    };
  };
}
