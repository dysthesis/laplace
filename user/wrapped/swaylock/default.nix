{
  lib,
  pkgs,
  swaylock-effects,
  ...
}: let
  wallpaper = "${../../assets/wallpaper.png}";

  tokens = [
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
in
  lib.laplace.pkgs.mkWrapper pkgs swaylock-effects {addFlags = tokens;}
