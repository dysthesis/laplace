{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    isBool
    isString
    ;
  inherit (lib.generators) toINI;
  inherit (lib.babel.pkgs) mkWrapper;
  # From home-manager
  yesNo = value: if value then "yes" else "no";
  toDunstIni = toINI {
    mkKeyValue =
      key: value:
      let
        value' =
          if isBool value then
            (yesNo value)
          else if isString value then
            ''"${value}"''
          else
            toString value;
      in
      "${key}=${value'}";
  };
  config = import ./config.nix;
  dunstrc = pkgs.writeText "dunstrc" ''
    ${toDunstIni config}
  '';
in
mkWrapper pkgs pkgs.dunst ''
  wrapProgram $out/bin/dunst \
   --add-flags "--config ${dunstrc}"
''
