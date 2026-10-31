{
  lib,
  pkgs,
  lazygit,
  generate-commit,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  cfg = pkgs.writers.writeYAML "lazygit.yml" (import ./config.nix {inherit lib generate-commit;});
in
  mkWrapper pkgs lazygit {
    addFlags = ["--use-config-file=${cfg}"];
    binPath = [pkgs.git];
  }
