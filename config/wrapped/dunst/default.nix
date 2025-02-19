{
  pkgs,
  lib,
  ...
}: let
  inherit
    (lib)
    isBool
    isString
    ;
  inherit (lib.generators) toINI;
  inherit (lib.babel.pkgs) mkWrapper;
  # From home-manager
  toDunstIni = toINI {
    mkKeyValue = key: value: let
      value' =
        if isBool value
        then (lib.hm.booleans.yesNo value)
        else if isString value
        then ''"${value}"''
        else toString value;
    in "${key}=${value'}";
  };
  config = import ./config.nix;
in
  mkWrapper pkgs pkgs.dunst ''
    wrapProgram $out/bin/dunst \
     --add-flags "--config ${toDunstIni config}"
  ''
