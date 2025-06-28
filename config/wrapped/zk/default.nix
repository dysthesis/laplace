{
  pkgs,
  lib,
  zk,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs zk
  /*
  bash
  */
  ''
    wrapProgram $out/bin/zk \
      --set ZK_NOTEBOOK_DIR "~/Documents/Notes/Contents/"
  ''
