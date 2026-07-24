{
  pkgs,
  lib,
  delta,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  features = [
    "side-by-side"
    "unobtrusive-line-numbers"
    "decorations"
    "ansi"
  ];
  formatFeatures = features:
    features
    |> map (feat: "+${feat}")
    |> builtins.concatStringsSep " ";
  formattedFeatures = formatFeatures features;
in
  mkWrapper pkgs delta {set.DELTA_FEATURES = formattedFeatures;}
