{
  config,
  lib,
  ...
}: let
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
  options.laplace.hardware = {
    monitors = mkOption {
      type = listOf (submodule {
        options = {
          name = mkOption {
            type = str;
            example = "DP-1";
          };

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
            default = 1;
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

    battery.name = mkOption {
      type = nullOr str;
      default = null;
      example = "BAT1";
      description = "Battery device name for desktop widgets, or null when absent.";
    };

    backlight.device = mkOption {
      type = nullOr str;
      default = null;
      example = "amdgpu_bl0";
      description = "Backlight device name for desktop widgets, or null when absent.";
    };
  };

  config.assertions = [
    {
      assertion =
        builtins.length
        (builtins.filter (monitor: monitor.primary or false) config.laplace.hardware.monitors)
        <= 1;
      message = "Only one laplace.hardware.monitors entry may set primary = true";
    }
  ];
}
