{
  pkgs,
  lib,
  helix,
  callPackage,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  config = callPackage ./config.nix { inherit pkgs; };
in
mkWrapper pkgs helix
  # bash
  ''
    wrapProgram $out/bin/hx \
      --add-flags "-c ${config}"
  ''
