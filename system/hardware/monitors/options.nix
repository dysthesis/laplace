{lib, ...}: let
  inherit (lib) mkOption;
  inherit
    (lib.types)
    oneOf
    nullOr
    str
    float
    int
    bool
    listOf
    submodule
    ;
in {
  options.laplace.hardware.monitors = mkOption {
    type = listOf (submodule {
      options = {
        name = mkOption {
          type = str;
          example = "DP-1";
        };

        # TODO: Add check to ensure that only one primary monitor exist
        primary = mkOption {
          type = bool;
          example = true;
          default = false;
          description = "Whether the current monitor is the primary monitor";
        };

        width = mkOption {
          type = int;
          example = 1920;
        };

        height = mkOption {
          type = int;
          example = 1080;
        };

        refreshRate = mkOption {
          type = oneOf [
            int
            float
          ];
          default = 60;
        };

        scale = mkOption {
          type = nullOr (oneOf [
            int
            float
          ]);
          default = null;
          description = "Output scale used by compositors that support per-monitor scaling.";
        };

        variableRefreshRate = mkOption {
          type = bool;
          default = false;
          description = "Whether compositors should enable variable refresh rate for this monitor.";
        };

        pos = {
          x = mkOption {
            type = nullOr int;
            default = null;
          };

          y = mkOption {
            type = nullOr int;
            default = null;
          };
        };

        enabled = mkOption {
          type = bool;
          default = true;
        };
      };
    });
    default = [];
  };
}
