{
  lib,
  pkgs,
  lazygit,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  cfg = pkgs.writers.writeYAML (import ./config.nix {});
in
  mkWrapper pkgs lazygit {addFlags = [''--use-config-file="${cfg}"''];}
