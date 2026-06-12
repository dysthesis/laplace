{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  cfg = config.laplace.display;
  enabled = elem "wayland" cfg.servers && cfg.wayland.compositor == "dwl";
in {
  # dwl's baked-in autostart spawns its own companions (dunst, wbg).
  config = lib.mkIf enabled {
    laplace.display.wayland.sessionCommand = lib.getExe' pkgs.configured.dwl "dwl";
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.dwl "dwl"}
      ''
    ];
  };
}
