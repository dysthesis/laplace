{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  inherit (lib.babel.pkgs) mkWrapper;
  config = import ./config {inherit pkgs lib;};
in
  mkWrapper pkgs pkgs.river
  /*
  sh
  */
  ''
    wrapProgram $out/bin/river \
      --add-flags "-c ${getExe config}"
  ''
