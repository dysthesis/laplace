{
  lib,
  pkgs,
  integrated,
  swaylock-effects,
  ...
}: let
  palette = import ../../../system/display/servers/wayland/desktop/palette.nix;
  colour = name: lib.removePrefix "#" palette.${name};
  wallpaper = "${../../assets/wallpaper.png}";

  legacyTokens = [
    "--clock"
    "--effect-blur"
    "7x5"
    "--font"
    "IosevkaCadmus Nerd Font"
    "--effect-vignette"
    "0.5:0.5"
    "--image"
    wallpaper
    "--indicator"
    "--indicator-radius"
    "100"
    "--indicator-thickness"
    "7"
    "--effect-blur"
    "7x5"
    "--effect-vignette"
    "0.35:0.35"

    "--inside-color"
    "080808cc"
    "--inside-ver-color"
    "708090cc"
    "--inside-wrong-color"
    "d70000cc"
    "--inside-clear-color"
    "2a2a2acc"

    "--ring-color"
    "7a7a7a"
    "--ring-ver-color"
    "7788aa"
    "--ring-wrong-color"
    "d70000"
    "--ring-clear-color"
    "ffaa88"

    "--text-color"
    "ffffff"
    "--text-ver-color"
    "7788aa"
    "--text-wrong-color"
    "d70000"
    "--text-clear-color"
    "ffaa88"

    "--key-hl-color"
    "789978"
    "--bs-hl-color"
    "d70000"

    "--line-color"
    "00000000"
    "--line-ver-color"
    "00000000"
    "--line-wrong-color"
    "00000000"
    "--line-clear-color"
    "00000000"
    "--separator-color"
    "00000000"
  ];
  desktopTokens = [
    "--config"
    "${pkgs.writeText "swaylock-desktop.conf" ""}"
    "--color"
    (colour "background")
    "--font"
    "Atkinson Hyperlegible Next"
    "--font-size"
    "13"
    "--indicator-idle-visible"
    "--indicator-radius"
    "80"
    "--indicator-thickness"
    "3"
    "--inside-color"
    (colour "surface")
    "--inside-ver-color"
    (colour "surface")
    "--inside-wrong-color"
    (colour "surface")
    "--inside-clear-color"
    (colour "surface")
    "--inside-caps-lock-color"
    (colour "surface")
    "--ring-color"
    (colour "border")
    "--ring-ver-color"
    (colour "focus")
    "--ring-wrong-color"
    (colour "urgent")
    "--ring-clear-color"
    (colour "warning")
    "--ring-caps-lock-color"
    (colour "warning")
    "--text-color"
    (colour "foreground")
    "--text-ver-color"
    (colour "foreground")
    "--text-wrong-color"
    (colour "foreground")
    "--text-clear-color"
    (colour "foreground")
    "--text-caps-lock-color"
    (colour "foreground")
    "--key-hl-color"
    (colour "focus")
    "--bs-hl-color"
    (colour "warning")
    "--caps-lock-key-hl-color"
    (colour "warning")
    "--caps-lock-bs-hl-color"
    (colour "warning")
    "--line-color"
    (colour "surface")
    "--line-ver-color"
    (colour "surface")
    "--line-wrong-color"
    (colour "surface")
    "--line-clear-color"
    (colour "surface")
    "--line-caps-lock-color"
    (colour "surface")
    "--separator-color"
    (colour "surface")
  ];
  package =
    if integrated
    then pkgs.swaylock
    else swaylock-effects;
  tokens =
    if integrated
    then desktopTokens
    else legacyTokens;
in
  lib.laplace.pkgs.mkWrapper pkgs package {addFlags = tokens;}
