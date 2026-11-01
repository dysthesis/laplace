{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  cfg = config.laplace.display;
  enabled = elem "wayland" cfg.servers && cfg.wayland.compositor == "river";
in {
  # The River init wrapper starts swayidle, swaylock, swaybg, dunst and yambar.
  config = lib.mkIf enabled {
    laplace.display.wayland.sessionCommand = lib.getExe' pkgs.configured.river "river";
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.river "river"}
      ''
    ];
  };
}
