{
  pkgs,
  lib,
  jjui,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  config = import ./config.nix {};
  configFile = pkgs.writers.writeTOML "config.toml" config;
in
  mkWrapper pkgs jjui
  # sh
  ''
    wrapProgram $out/bin/jjui \
      --add-flags "--config ${configFile}"
  ''
