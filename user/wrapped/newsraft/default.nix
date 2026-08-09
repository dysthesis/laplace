{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  deps = with pkgs; [
    libnotify
  ];
in
  mkWrapper pkgs pkgs.newsraft {
    binPath = deps;
    addFlags = [
      "-c"
      "${./config}"
      "-f"
      "${./feeds}"
    ];
  }
