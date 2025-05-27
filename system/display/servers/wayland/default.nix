{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    fold
    ;
  inherit (lib.babel.pkgs) mkWrapper;
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
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
    systemd.user = {
      services = {
        wlsunset = {
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
        swaybg = {
          description = "Wayland Background Manager";
          bindsTo = ["graphical-session.target"];
          after = ["graphical-session.target"];
          partOf = ["graphical-session.target"];
          requisite = ["graphical-session.target"];
          wantedBy = ["graphical-session.target"];

          startLimitIntervalSec = 10;
          startLimitBurst = 5;
          script =
            #sh
            ''
              #!/bin/sh
              exec ${lib.getExe pkgs.swaybg} -i ${./wallpaper.png}
            '';
          serviceConfig.Restart = "on-failure";
        };
        wlr-randr = rec {
          description = "Wayland monitor setup";
          after = ["graphical-session.target"];
          partOf = ["graphical-session.target"];
          serviceConfig.Type = "oneshot";
          requires = after;
          script = let
            wlr-randr = lib.getExe pkgs.wlr-randr;
            wlr-randr-args =
              fold (
                curr: acc: "${acc} --output ${curr.name} --pos ${toString curr.pos.x},${toString curr.pos.y} --mode ${toString curr.width}x${toString curr.height}@${toString curr.refreshRate}Hz"
              ) ""
              config.laplace.hardware.monitors;
          in
            #sh
            ''
              #!/bin/sh
              exec ${wlr-randr} ${wlr-randr-args}
            '';
        };
        dwl = {
          description = "dwl - Wayland window manager";
          bindsTo = ["graphical-session.target"];
          wants = ["graphical-session-pre.target"];
          after = ["graphical-session-pre.target"];
          # We explicitly unset PATH here, as we want it to be set by
          # systemctl --user import-environment in startsway
          environment.PATH = lib.mkForce null;
          serviceConfig = let
            dwl = inputs.gungnir.packages.${pkgs.system}.dwl.override {
              enableXWayland = false;
            };
          in {
            Type = "simple";
            ExecStart = "${lib.getExe dwl}";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };
      };
      targets."dwl-session" = {
        description = "dwl compositor session";
        documentation = ["man:systemd.special(7)"];
        bindsTo = ["graphical-session.target"];
        wants = ["graphical-session-pre.target"];
        after = ["graphical-session-pre.target"];
      };
    };
  };
}
