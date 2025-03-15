{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  cfg = import ./config.nix { inherit pkgs config; };
in
mkWrapper pkgs inputs.babel.packages.${pkgs.system}.ghostty-hardened ''
  wrapProgram $out/bin/ghostty --add-flags "--config-file=${cfg}"
''
