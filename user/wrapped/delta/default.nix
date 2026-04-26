{
  pkgs,
  lib,
  delta,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  features = [
    "side-by-side"
    "unobtrusive-line-numbers"
    "decorations"
    "ansi"
  ];
  formatFeatures = features:
    features
    |> builtins.map (feat: "+${feat}")
    |> builtins.concatStringsSep " ";
  formattedFeatures = formatFeatures features;
in
  mkWrapper pkgs delta
  # sh
  ''
    wrapProgram $out/bin/delta \
      --set DELTA_FEATURES "${formattedFeatures}"
  ''
