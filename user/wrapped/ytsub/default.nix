{
  lib,
  pkgs,
  ytsub,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs ytsub {
    binPath = [
      pkgs.configured.mpv
    ];
  }
