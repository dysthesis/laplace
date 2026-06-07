{
  pkgs,
  lib,
  wezterm,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs wezterm
  # sh
  ''
    wrapProgram $out/bin/wezterm \
      --add-flags "--config-file ${./config.lua}"
  ''
