{
  lib,
  pkgs,
  fzf,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs fzf
  # sh
  ''
    wrapProgram $out/bin/fzf \
      --add-flags "--style full"
  ''
