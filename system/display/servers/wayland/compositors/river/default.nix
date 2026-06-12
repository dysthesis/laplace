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
  # river's wrapped init spawns its own companions (swayidle, swaylock,
  # swaybg, dunst, yambar).
  config = lib.mkIf enabled {
    laplace.display.wayland.sessionCommand = lib.getExe' pkgs.configured.river "river";
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.river "river"}
      ''
    ];
  };
}
