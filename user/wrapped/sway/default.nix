{
  inputs,
  pkgs,
  lib,
  callPackage,
  sway-unwrapped,
  config,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  configFile = callPackage ./config.nix {
    inherit
      lib
      pkgs
      config
      inputs
      ;
    sway = sway-unwrapped;
  };
in
  mkWrapper pkgs sway-unwrapped {addFlags = ["--config" configFile];}
