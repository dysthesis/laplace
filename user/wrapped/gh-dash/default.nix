{
  pkgs,
  lib,
  gh-dash,
  delta,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  config = import ./config.nix {inherit lib delta;};
  configFile = pkgs.writers.writeYAML "config.yml" config;
in
  mkWrapper pkgs gh-dash
  # sh
  ''
    wrapProgram $out/bin/gh-dash \
    --add-flags "--config ${configFile}"
  ''
