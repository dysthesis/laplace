{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  config = import ./config.nix { inherit pkgs; };
in
mkWrapper pkgs inputs.babel.packages.${pkgs.system}.ghostty-hardened ''
  wrapProgram $out/bin/ghostty --add-flags "--config-file=${config}"
''
