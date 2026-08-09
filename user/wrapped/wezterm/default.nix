{
  pkgs,
  lib,
  wezterm,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs wezterm {addFlags = ["--config-file" "${./config.lua}"];}
