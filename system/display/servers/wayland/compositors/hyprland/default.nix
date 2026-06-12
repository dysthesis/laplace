{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  cfg = config.laplace.display;
  enabled = elem "wayland" cfg.servers && cfg.wayland.compositor == "hyprland";
in {
  # hyprland's generated config spawns its own companions (waybar, dunst)
  # via exec-once.
  config = lib.mkIf enabled {
    laplace.display.wayland.sessionCommand = lib.getExe' pkgs.configured.hyprland "Hyprland";
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.hyprland "Hyprland"}
      ''
    ];
  };
}
