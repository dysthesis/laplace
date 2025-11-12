{
  pkgs,
  lib,
  helix,
  callPackage,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (lib) concatMapAttrsStringSep;
  inherit (pkgs) runCommandLocal;

  config = callPackage ./config.nix { inherit pkgs; };
  languagesConfig = callPackage ./languages.nix { inherit pkgs; };

  customThemes = {
    demiurge = callPackage ./theme.nix { inherit pkgs; };
  };
  themesDir = runCommandLocal "themes" { } ''
    mkdir -pv $out
    ${concatMapAttrsStringSep "\n" (name: theme: /* sh */ "cp ${theme} $out/${name}.toml") customThemes}
  '';
  runtime = pkgs.runCommandLocal "hx-runtime" { } ''
    mkdir -pv $out
    cp -r ${themesDir} $out/themes
    cp ${languagesConfig} $out/languages.toml
  '';
in
mkWrapper pkgs helix
  # bash
  ''
    wrapProgram $out/bin/hx \
      --add-flags "-c ${config}" \
      --set HELIX_RUNTIME "${runtime}"
  ''
