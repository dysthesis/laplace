{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    ;
  inherit (builtins) elem;
  cfg = config.laplace.display.servers;
in {
  config = mkIf (elem "wayland" cfg) {
    xdg.portal = {
      wlr.enable = true;
      config.common.default = "*";
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
    systemd.user = {
      targets.dwl-session = {
        description = "dwl compositor session";
        documentation = ["man:systemd.special(7)"];
        bindsTo = ["graphical-session.target"];
        after = ["graphical-session.target"];
      };
    };
  };
}
