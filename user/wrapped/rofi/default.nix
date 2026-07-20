{
  lib,
  pkgs,
  rofi-wayland,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  # No flags: symlinkJoin only, purely to land rofi in the `configured` set.
  mkWrapper pkgs rofi-wayland {}
