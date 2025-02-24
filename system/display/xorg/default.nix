{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.display;
in
{
  config = mkIf (elem "xorg" cfg) {
    services.xserver = {
      enable = true;
      displayManager = {
        # Use this until I figure out how to wrap xinit
        # Okay this seems to work, just not startx
        startx.enable = true;

        # Expose variables to graphical systemd user services
        importedVariables = [
          "GDK_SCALE"
          "GDK_DPI_SCALE"
          "QT_AUTO_SCREEN_SCALE_FACTOR"
        ];
      };
      excludePackages = with pkgs; [
        xterm
      ];
      dpi = 180;
      xrandrHeads = map (curr: {
        inherit (curr) primary;
        output = curr.name;
        monitorConfig = ''
          Option "PreferredMode" "${toString curr.width}x${toString curr.height}_${toString curr.refreshRate}.00"
          Option "Position" "${toString curr.pos.x} ${toString curr.pos.y}"
        '';
      }) config.laplace.hardware.monitors;
    };

    environment.variables = {
      ## Used by GTK 3
      # `GDK_SCALE` is limited to integer values
      GDK_SCALE = "1";
      # Inverse of GDK_SCALE
      GDK_DPI_SCALE = "1";

      # Used by Qt 5
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";

      _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
    };

    services.redshift.enable = true;
  };
}
