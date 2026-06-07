{
  lib,
  pkgs,
  read,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs read
  # sh
  ''
    wrapProgram $out/bin/rd \
      --set URLS "${./feeds}" \
  ''
