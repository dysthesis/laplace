{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs pkgs.newsraft ''
    wrapProgram $out/bin/newsraft \
      --add-flags "-c ${./config}" \
      --add-flags "-f ${./feeds}"
  ''
