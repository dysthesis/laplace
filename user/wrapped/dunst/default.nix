{
  pkgs,
  lib,
  config,
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
  yesNo = value:
    if value
    then "yes"
    else "no";
  toDunstIni = toINI {
    mkKeyValue = key: value: let
      value' =
        if isBool value
        then (yesNo value)
        else if isString value
        then ''"${value}"''
        else toString value;
    in "${key}=${value'}";
  };
  cfg = import ./config.nix {inherit config;};
  dunstrc = pkgs.writeText "dunstrc" ''
    ${toDunstIni cfg}
  '';
in
  mkWrapper pkgs pkgs.dunst ''
    wrapProgram $out/bin/dunst \
     --add-flags "-config ${dunstrc}"
  ''
