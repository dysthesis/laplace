{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  inherit (lib.laplace.pkgs) mkWrapper;
  config = import ./config {inherit pkgs lib;};
in
  mkWrapper pkgs pkgs.river {addFlags = ["-c" (getExe config)];}
