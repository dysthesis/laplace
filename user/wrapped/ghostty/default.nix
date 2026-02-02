{
  inputs,
  lib,
  pkgs,
  config,
  withDecorations ? false,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
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
  mkWrapper pkgs inputs.nixpressions.packages.${pkgs.system}.ghostty-hardened ''
    wrapProgram $out/bin/ghostty \
      --add-flags "--config-file=${cfg}" \
      --prefix PATH ":" "${lib.makeBinPath deps}"
  ''
