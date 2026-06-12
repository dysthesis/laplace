{
  config,
  lib,
  ...
}: let
  inherit (builtins) elem;
  isWayland = elem "wayland" config.laplace.display.servers;
in {
  imports = [
    (lib.laplace.modules.mkSelector {
      dir = ./compositors;
      option = ["laplace" "display" "wayland" "compositor"];
      description = "Which Wayland compositor to run";
      multiple = false;
      default = "niri";
    })
  ];

  # Set by the selected compositor module; the bash wrapper execs this on
  # VT1 login instead of hardcoding a compositor.
  options.laplace.display.wayland.sessionCommand = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    internal = true;
    description = "Command login shells exec to start the Wayland session.";
  };

  config = lib.mkIf isWayland {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
