{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  inherit (lib.cli) toGNUCommandLineShell;
  cfg = config.laplace.display.servers;
in {
  config = mkIf (elem "wayland" cfg) {
    xdg.portal = {
      wlr.enable = true;
      config.common.default = "*";
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    systemd.user.services.wlsunset = {
      enable = true;
      description = "Day/night gamma adjustments for Wayland compositors.";
      partOf = ["graphical-session.target"];

      script = let
        args = toGNUCommandLineShell {} {
          t = "3700";
          T = "6200";
          g = "1.0";
          l = config.location.latitude;
          L = config.location.longitude;
        };
      in "${pkgs.wlsunset}/bin/wlsunset ${args}";

      wantedBy = ["graphical-session.target"];
    };
  };
}
