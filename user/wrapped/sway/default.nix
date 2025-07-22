{
  inputs,
  pkgs,
  lib,
  callPackage,
  sway-unwrapped,
  config,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  configFile = callPackage ./config.nix {
    inherit lib pkgs config inputs;
    sway = sway-unwrapped;
  };
in
  mkWrapper pkgs sway-unwrapped
  /*
  bash
  */
  ''
    wrapProgram $out/bin/sway \
      --add-flags "--config ${configFile}"
  ''
