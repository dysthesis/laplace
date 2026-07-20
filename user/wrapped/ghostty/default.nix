{
  lib,
  pkgs,
  config,
  withDecorations ? false,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  cfg = import ./config.nix {
    inherit
      pkgs
      config
      lib
      withDecorations
      ;
  };
  deps = with pkgs; [
    configured.tmux
  ];
in
  mkWrapper pkgs pkgs.unstable.ghostty {
    addFlags = ["--config-file=${cfg}"];
    binPath = deps;
  }
