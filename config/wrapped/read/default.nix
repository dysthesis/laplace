{
  lib,
  pkgs,
  read,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs read
  # sh
  ''
    wrapProgram $out/bin/read \
      --add-flags "${./feeds}" \
      --add-flags "64"
  ''
