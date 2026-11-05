{
  name = "river";
  protocol = "wayland";
  configure = {
    lib,
    pkgs,
    ...
  }: {
    # The init wrapper owns swayidle, swaylock, swaybg, Dunst and Yambar.
    laplace.wm = {
      protocol = "wayland";
      login = [(lib.getExe' pkgs.configured.river "river")];
    };
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.river "river"}
      ''
    ];
  };
}
