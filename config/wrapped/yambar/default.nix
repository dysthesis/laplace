{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs pkgs.yambar
  /*
  sh
  */
  ''
    wrapProgram $out/bin/yambar \
     --add-flags "--config=${./config.yml}"
  ''
