{
  name = "hyprland";
  protocol = "wayland";
  configure = {
    lib,
    pkgs,
    ...
  }: {
    # The custom configuration owns Waybar and Dunst startup.
    laplace.wm = {
      protocol = "wayland";
      login = [(lib.getExe' pkgs.configured.hyprland "Hyprland")];
    };
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.hyprland "Hyprland"}
      ''
    ];
  };
}
