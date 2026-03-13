{
  pkgs,
  lib,
  direnv,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  direnvConfig = {
    global = {
      log_format = "-";
      log_filter = "^$";
    };
  };
  direnvConfigFile = pkgs.writers.writeTOML "direnv.toml" direnvConfig;
  direnvConfigDir = pkgs.runCommandNoCCLocal "direnv-config" {} ''
     mkdir -pv $out/direnv
    cp ${direnvConfigFile} $out/direnv/direnv.toml
  '';
in
  mkWrapper pkgs.unstable direnv ''
    wrapProgram $out/bin/direnv \
      --set XDG_CONFIG_HOME "${direnvConfigDir}"
  ''
