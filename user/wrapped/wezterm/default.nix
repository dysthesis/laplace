{
  pkgs,
  lib,
  wezterm,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs wezterm
  # sh
  ''
    wrapProgram $out/bin/wezterm \
      --add-flags "--config-file ${./config.lua}"
  ''
