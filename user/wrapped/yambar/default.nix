{
  pkgs,
  lib,
  cacheDir,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  config = import ./config.nix {inherit pkgs cacheDir;};
in
  mkWrapper pkgs pkgs.yambar {addFlags = ["--config=${config}"];}
