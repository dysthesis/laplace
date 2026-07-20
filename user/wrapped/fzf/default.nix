{
  lib,
  pkgs,
  fzf,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs fzf {addFlags = ["--style full"];}
