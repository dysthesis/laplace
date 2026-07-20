{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  deps = with pkgs; [python3];
in
  mkWrapper pkgs pkgs.timewarrior {
    set.TIMEWARRIORDB = "/home/demiurge/.local/share/timewarrior";
    binPath = deps;
  }
