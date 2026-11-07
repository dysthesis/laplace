{
  config,
  pkgs,
  lib,
  ...
}: let
  palette = import ../../../system/display/servers/wayland/desktop/palette.nix;
  hex = lib.removePrefix "#";
  fontSize = config.laplace.display.foot.fontSize;

  lineHeight = fontSize * 1.5;
  padding = 10;

  mkConfig = cfg:
    cfg
    |> lib.generators.toINI {}
    |> pkgs.writeText "foot.ini";
in
  mkConfig {
    main = {
      term = "foot";
      shell = lib.getExe pkgs.configured.fish;
      font = "IosevkaCadmus Nerd Font:size=${toString fontSize}";
      line-height = toString lineHeight;
      pad = "${toString padding}x${toString padding}";
      dpi-aware = "yes";
      bold-text-in-bright = "no";
      selection-target = "primary";
      initial-window-mode = "windowed";
    };
    tweak.ligatures = "yes";
    colors-dark = {
      background = hex palette.background;
      foreground = hex palette.foreground;
      regular0 = hex palette.inset;
      regular1 = hex palette.urgent;
      regular2 = hex palette.success;
      regular3 = hex palette.caution;
      regular4 = hex palette.focus;
      regular5 = hex palette.warning;
      regular6 = hex palette.info;
      regular7 = hex palette.foreground;
      bright0 = hex palette.border;
      bright1 = hex palette.urgent;
      bright2 = hex palette.success;
      bright3 = hex palette.warning;
      bright4 = hex palette.focus;
      bright5 = hex palette.warning;
      bright6 = hex palette.info;
      bright7 = hex palette.foreground;
      cursor = "${hex palette.background} ${hex palette.foreground}";
      selection-background = hex palette.focus;
      selection-foreground = hex palette.background;
    };
  }
