{
  lib,
  pkgs,
  ytsub,
  ...
}: let
  inherit (lib) makeBinPath;
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs ytsub { }
