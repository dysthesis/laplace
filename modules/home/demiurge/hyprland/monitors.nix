{systemConfig, ...}: {
  wayland.windowManager.hyprland.settings.monitor =
    map (
      monitor: let
        resolution = "${toString monitor.width}x${toString monitor.height}@${toString monitor.refreshRate}";
        position = "${toString monitor.pos.x}x${toString monitor.pos.y}";
      in "${monitor.name},${
        if monitor.enabled
        then "${resolution},${position},1"
        else "disable"
      }"
    )
    systemConfig.laplace.hardware.monitors;
}
