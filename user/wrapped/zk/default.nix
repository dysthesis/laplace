{
  pkgs,
  lib,
  zk,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs zk {set.ZK_NOTEBOOK_DIR = "/home/demiurge/Documents/Notes/Contents/";}
