{
  lib,
  pkgs,
  read,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
in
mkWrapper pkgs read
  # sh
  ''
    wrapProgram $out/bin/rd \
      --set URLS "${./feeds}" \
  ''
