{
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (pkgs.writers) writeTOML;
  cfg = writeTOML "bibiman-config" (import ./config.nix {inherit inputs pkgs lib;});
in
  mkWrapper pkgs pkgs.unstable.bibiman {addFlags = ["--config-file=${cfg}"];}
