{
  lib,
  pkgs,
  fzf,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs fzf
  # sh
  ''
    wrapProgram $out/bin/fzf \
      --add-flags "--style full"
  ''
