{
  lib,
  pkgs,
  rofi-wayland,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs rofi-wayland
  # sh
  ''
    wrapProgram $out/bin/rofi
  ''
