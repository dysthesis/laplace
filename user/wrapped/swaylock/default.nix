{
  lib,
  pkgs,
  self,
  swaylock-effects,
  ...
}: let
  inherit (builtins) concatStringsSep;
  wallpaper = "${self}/user/wallpaper.png";

  tokens = [
    "--clock"
    "--effect-blur"
    "7x5"
    "--font"
    "JBMono Nerd Font"
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

  mkParam = s:
    if lib.hasInfix " " s
    then ''--add-flag ${lib.escapeShellArg s}''
    else ''--add-flags ${lib.escapeShellArg s}'';

  formatted = concatStringsSep " \\\n      " (map mkParam tokens);
in
  lib.babel.pkgs.mkWrapper pkgs swaylock-effects ''
    wrapProgram "$out/bin/swaylock" \
      ${formatted}
  ''
