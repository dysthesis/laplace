{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.display;
in
{
  config = mkIf (cfg == "xorg") {
    services.xserver = {
      enable = true;
      windowManager = {
        dwm = {
          enable = true;
          package = inputs.gungnir.packages.${pkgs.system}.dwm;
        };
        session = [
          {
            name = "dwm";
            start = ''
              dont_stop() {
                while type dwm >/dev/null ; do dwm && continue || break ; done
              }

              ${inputs.gungnir.packages.${pkgs.system}.dwm-bar} &
              dont_stop &
              waitPID=$!
            '';
          }
        ];
      };
      displayManager = {
        defaultSession = "none+dwm";
        # Use this until I figure out how to wrap xinit
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
    };

    environment.variables = {
      ## Used by GTK 3
      # `GDK_SCALE` is limited to integer values
      GDK_SCALE = "2";
      # Inverse of GDK_SCALE
      GDK_DPI_SCALE = "0.5";

      # Used by Qt 5
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";

      _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
    };
  };
}
