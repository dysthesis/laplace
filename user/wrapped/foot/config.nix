{
  config,
  pkgs,
  lib,
  ...
}: let
  host = config.networking.hostName or "";
  fontSize =
    if host == "phobos"
    then 5.5
    else 9;
  lineHeight = fontSize * 1.5;
  padding = 10;
in
  pkgs.writeText "foot.ini" ''
    [main]
    term=foot
    shell=${lib.getExe pkgs.configured.fish}
    font=JBMono Nerd Font:size=${toString fontSize}
    line-height=${toString lineHeight}
    pad=${toString padding}x${toString padding}
    dpi-aware=yes
    bold-text-in-bright=no
    selection-target=primary
    initial-window-mode=windowed

    [tweak]
    ligatures=yes

    [colors-dark]
    background=000000
    foreground=deeeed
    regular0=080808
    regular1=d70000
    regular2=789978
    regular3=ffaa88
    regular4=7788aa
    regular5=d7007d
    regular6=708090
    regular7=deeeed
    bright0=444444
    bright1=d70000
    bright2=789978
    bright3=ffaa88
    bright4=7788aa
    bright5=d7007d
    bright6=708090
    bright7=deeeed
    cursor=deeeed deeeed
    selection-background=7a7a7a
    selection-foreground=0a0a0a
  ''
