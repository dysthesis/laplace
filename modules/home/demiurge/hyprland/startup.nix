{pkgs, ...}: {
  wayland.windowManager.hyprland.settings.exec-once = [
    "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP"
    "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP"
    "${pkgs.dunst}"
    "${pkgs.waybar}"
    "${pkgs.udiske}"

    # TODO: Create an option to adjust wlsunset per-device
    "${pkgs.wlsunset} -l -33.9 -L 151.2"
  ];
}
