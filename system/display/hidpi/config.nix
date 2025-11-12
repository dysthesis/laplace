{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.display.hidpi;
in
{
  config = mkIf cfg {
    services.xserver = {
      dpi = 180;
      displayManager.importedVariables = [
        "GDK_SCALE"
        "GDK_DPI_SCALE"
        "QT_AUTO_SCREEN_SCALE_FACTOR"
      ];
    };
    environment.variables = {
      _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
    }
    // mkIf (config.networking.hostName == "deimos") {
      ## Used by GTK 3
      # `GDK_SCALE` is limited to integer values
      GDK_SCALE = "2";
      # Inverse of GDK_SCALE
      GDK_DPI_SCALE = "0.5";

      # Used by Qt 5
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    };
  };
}
