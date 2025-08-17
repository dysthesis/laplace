{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.networking.hostName == "phobos";
  fontSize =
    if cfg
    then 9
    else 9;
  padding = 10;
in
  pkgs.writeText "ghostty-config" ''
    adjust-cell-height = 20%
    font-family = JetBrainsMono Nerd Font
    font-feature = calt
    font-feature = clig
    font-feature = liga
    font-feature = ss20
    font-feature = cv02
    font-feature = cv03
    font-feature = cv04
    font-feature = cv05
    font-feature = cv06
    font-feature = cv07
    font-feature = cv11
    font-feature = cv14
    font-feature = cv15
    font-feature = cv16
    font-feature = cv17
    font-size = ${toString fontSize}
    window-padding-x = ${toString padding}
    window-padding-y = ${toString padding}
    background-opacity = 1
    window-decoration = false
    confirm-close-surface = false
    command = ${lib.getExe pkgs.configured.fish}


    ## Lackluster
    # https://github.com/slugbyte/lackluster.nvim/blob/662fba7e6719b7afc155076385c00d79290bc347/extra/ghostty/lackluster

    palette = 0=#080808
    palette = 1=#d70000
    palette = 2=#789978
    palette = 3=#ffaa88
    palette = 4=#7788aa
    palette = 5=#d7007d
    palette = 6=#708090
    palette = 7=#deeeed
    palette = 8=#444444
    palette = 9=#d70000
    palette = 10=#789978
    palette = 11=#ffaa88
    palette = 12=#7788aa
    palette = 13=#d7007d
    palette = 14=#708090
    palette = 15=#deeeed
    background = 000000
    foreground = deeeed
    cursor-color = deeeed
    selection-background = 7a7a7a
    selection-foreground = 0a0a0a

    # Bindings
    keybind = ctrl+enter=unbind
  ''
