{
  pkgs,
  lib,
  zk,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs zk
  # bash
  ''
    wrapProgram $out/bin/zk \
      --set ZK_NOTEBOOK_DIR "/home/demiurge/Documents/Notes/Contents/"
  ''
