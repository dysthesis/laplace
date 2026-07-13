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
    # from https://github.com/NotAShelf/nyx/blob/319b1f6fe4d09ff84d83d1f8fa0d04e0220dfed7/modules/core/common/system/security/apparmor.nix#L7
    services.dbus.apparmor = "disabled";

    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = true;
      packages = [pkgs.apparmor-profiles];
    };
  };
}
