{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    str
    int
    bool
    listOf
    submodule
    ;
in
{
  options.laplace.hardware.monitors = mkOption {
    type = listOf (submodule {
      options = {
        name = mkOption {
          type = str;
          example = "DP-1";
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
          type = int;
          default = 60;
        };

        pos = {
          x = mkOption {
            type = int;
            default = 0;
          };

          y = mkOption {
            type = int;
            default = 0;
          };
        };

        enabled = mkOption {
          type = bool;
          default = true;
        };
      };
    });
    default = [ ];
  };
}
