{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  waybarConfig = import ./config.nix {inherit config pkgs;};
  style = import ./style.nix {
    inherit config pkgs lib;
  };
in
  mkWrapper pkgs pkgs.waybar
  # sh
  ''
    wrapProgram $out/bin/waybar \
      --add-flags "-c ${waybarConfig}" \
      --add-flags "-s ${style}"
  ''
