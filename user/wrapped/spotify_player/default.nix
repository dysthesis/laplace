{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs pkgs.spotify-player {addFlags = ["-c ${./config}"];}
