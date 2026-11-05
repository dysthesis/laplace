{
  name = "sway";
  protocol = "wayland";
  configure = {
    lib,
    pkgs,
    ...
  }: {
    # The custom configuration owns swaybar, swayidle, wlsunset and Dunst.
    laplace.wm = {
      protocol = "wayland";
      login = [(lib.getExe' pkgs.configured.sway "sway")];
    };
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.sway "sway"}
      ''
    ];
  };
}
