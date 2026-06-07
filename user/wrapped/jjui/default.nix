{
  pkgs,
  lib,
  jjui,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  config = import ./config.nix {};
  configFile = pkgs.writers.writeTOML "config.toml" config;
  configDir = pkgs.runCommandLocal "jjui-config" {} ''
    mkdir -pv $out
    cp ${configFile} $out/config.toml
  '';
in
  mkWrapper pkgs jjui
  # sh
  ''
    wrapProgram $out/bin/jjui \
      --set JJUI_CONFIG_DIR ${configDir}
  ''
