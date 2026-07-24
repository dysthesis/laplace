{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  cfg = config.laplace.display;
  enabled = elem "wayland" cfg.servers && cfg.wayland.compositor == "sway";
in {
  # Sway starts swayidle, wlsunset, and dunst, but no status bar.
  config = lib.mkIf enabled {
    laplace.display.wayland.sessionCommand = lib.getExe' pkgs.configured.sway "sway";
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.sway "sway"}
      ''
    ];
  };
}
