{
  wayland = import ./servers/wayland;
  xorg = import ./servers/xorg;
  niri = import ./servers/wayland/compositors/niri;
  hyprland = import ./servers/wayland/compositors/hyprland;
  sway = import ./servers/wayland/compositors/sway;
  river = import ./servers/wayland/compositors/river;
  dwl = import ./servers/wayland/compositors/dwl;
  xmonad = import ./servers/xorg/sessions/xmonad;

  noctalia = {
    name = "noctalia";
    build = args: import ../../user/wrapped/noctalia (args // {noctalia = args.pkgs.unstable.noctalia;});
    configure = import ./servers/wayland/desktop;
  };
  waybar = {
    name = "waybar";
    build = import ../../user/wrapped/waybar;
  };
  foot = {
    name = "foot";
    build = import ../../user/wrapped/foot/operations.nix;
  };
  vicinae = {
    name = "vicinae";
    build = import ./launchers/vicinae.nix;
  };
  fuzzel = {
    name = "fuzzel";
    build = import ./launchers/fuzzel.nix;
  };
}
