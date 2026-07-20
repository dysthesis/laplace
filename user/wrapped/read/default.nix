{
  lib,
  pkgs,
  read,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs read {
    program = "rd"; # wrapped binary is `rd`, not the package name
    set.URLS = "${./feeds}";
  }
