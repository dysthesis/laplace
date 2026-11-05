let
  terminal = ../../user/wrapped/foot/operations.nix;
  launcher = ./launchers/fuzzel.nix;
  niri = import ./servers/wayland/compositors/niri;
in rec {
  standalone = {
    wm = niri;
    shell = null;
    bar = ../../user/wrapped/waybar;
    inherit terminal launcher;
  };
  integrated =
    standalone
    // {
      shell = ./servers/wayland/desktop;
      bar = null;
      launcher = ./launchers/vicinae.nix;
    };
  legacy = wm: {
    inherit wm terminal launcher;
    shell = null;
    bar = null;
  };
  none = legacy null;
}
