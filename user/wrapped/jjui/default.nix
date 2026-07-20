{
  pkgs,
  lib,
  jjui,
  jujutsu,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  config = import ./config.nix {
    inherit lib;
    jjAliases = jujutsu.jjConfig.aliases;
  };
  configFile = pkgs.writers.writeTOML "config.toml" config;
  configDir = pkgs.runCommandLocal "jjui-config" {} ''
    mkdir -pv $out
    cp ${configFile} $out/config.toml
  '';
in
  mkWrapper pkgs jjui {
    set.JJUI_CONFIG_DIR = configDir;
    binPath = [jujutsu];
  }
