{
  pkgs,
  lib,
  gh-dash,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  config = import ./config.nix {};
  configFile = pkgs.writers.writeYAML "config.yml" config;
in
  mkWrapper pkgs gh-dash
  # sh
  ''
    wrapProgram $out/bin/gh-dash \
    --add-flags "--config ${configFile}"
  ''
