{
  pkgs,
  lib,
  helix,
  helixUnwrapped,
  callPackage,
  ...
}: let
  inherit (lib) concatMapAttrsStringSep makeBinPath;
  inherit (pkgs) runCommandLocal;

  config = callPackage ./config.nix {inherit pkgs;};
  languagesConfig = callPackage ./languages.nix {inherit pkgs;};
  runtimeInputs = with pkgs.unstable; [
    alejandra
    nil
    nixd
  ];

  customThemes = {
    demiurge = callPackage ./theme.nix {inherit pkgs;};
  };
  themesDir = runCommandLocal "themes" {} ''
    mkdir -pv $out
    ${concatMapAttrsStringSep "\n" (name: theme:
      /*
      sh
      */
      "cp ${theme} $out/${name}.toml")
    customThemes}
  '';
  configDir = runCommandLocal "helix-config-dir" {} ''
    mkdir -pv $out/helix
    ln -sv ${config} $out/helix/config.toml
    ln -sv ${languagesConfig} $out/helix/languages.toml
  '';
  runtime = runCommandLocal "hx-runtime" {} ''
    mkdir -pv $out
    cp -r ${helix.runtime}/* $out/
    chmod -R u+w $out
    mkdir -pv $out/themes
    cp ${themesDir}/* $out/themes/
  '';
in
  runCommandLocal "${helixUnwrapped.name}-wrapped" {
    nativeBuildInputs = [pkgs.makeWrapper];
  }
  # bash
  ''
    cp -r ${helixUnwrapped} $out
    chmod -R u+w $out
    ln -sv ${runtime} $out/bin/runtime
    wrapProgram $out/bin/hx \
      --set HELIX_RUNTIME "${runtime}" \
      --set XDG_CONFIG_HOME "${configDir}" \
      --prefix PATH : "${makeBinPath runtimeInputs}"
  ''
