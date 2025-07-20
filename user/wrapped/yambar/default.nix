{
  pkgs,
  lib,
  cacheDir,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  config = import ./config.nix { inherit pkgs cacheDir; };
in
mkWrapper pkgs pkgs.yambar
  # sh
  ''
    wrapProgram $out/bin/yambar \
     --add-flags "--config=${config}"
  ''
