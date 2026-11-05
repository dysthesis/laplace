{
  config,
  pkgs,
  lib,
  integrated,
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
    colors-dark =
      if integrated
      then {
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
      }
      else {
        background = "000000";
        foreground = "ffffff";
        regular0 = "080808";
        regular1 = "d70000";
        regular2 = "789978";
        regular3 = "ffaa88";
        regular4 = "7788aa";
        regular5 = "d7007d";
        regular6 = "708090";
        regular7 = "deeeed";
        bright0 = "444444";
        bright1 = "d70000";
        bright2 = "789978";
        bright3 = "ffaa88";
        bright4 = "7788aa";
        bright5 = "d7007d";
        bright6 = "708090";
        bright7 = "deeeed";
        cursor = "deeeed deeeed";
        selection-background = "7a7a7a";
        selection-foreground = "0a0a0a";
      };
  }
