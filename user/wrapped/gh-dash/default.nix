{
  pkgs,
  lib,
  gh,
  gh-dash,
  writeShellScript,
  delta,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  config = import ./config.nix {inherit lib delta gh writeShellScript;};
  configFile = pkgs.writers.writeYAML "config.yml" config;
in
  mkWrapper pkgs gh-dash {addFlags = ["--config ${configFile}"];}
