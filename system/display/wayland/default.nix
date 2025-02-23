{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib.cli) toGNUCommandLineShell;
  cfg = config.laplace.display;
in {
  config = mkIf (cfg == "wayland") {
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    systemd.user.services.wlsunset = {
      Unit = {
        Description = "Day/night gamma adjustments for Wayland compositors.";
        PartOf = ["graphical-session.target"];
      };

      Service = {
        ExecStart = let
          args = toGNUCommandLineShell {} {
            t = "3700";
            T = "6200";
            g = "1.0";
            l = config.location.latitude;
            L = config.location.longitude;
          };
        in "${cfg.package}/bin/wlsunset ${args}";
      };

      Install = {WantedBy = [cfg.systemdTarget];};
    };
  };
}
