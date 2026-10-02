{
  pkgs,
  lib,
  opencode,
  rtk,
  uv,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs opencode {
    binPath = [
      rtk
      uv
      pkgs.configured.serena
    ];
    set = {
      OPENCODE_ENABLE_EXA = true;
      OPENCODE_EXPERIMENTAL_LSP_TOOL = true;
      OPENCODE_DISABLE_AUTOCOMPACT = true;
      OPENCODE_DISABLE_PRUNE = true;
    };
  }
