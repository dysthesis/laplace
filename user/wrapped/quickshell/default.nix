{
  pkgs,
  lib,
  config,
  quickshell ? pkgs.quickshell,
  ...
}: let
  palette = import ../../../system/display/servers/wayland/desktop/palette.nix;
  monitors = config.laplace.hardware.monitors;
  primary =
    lib.findFirst (monitor: monitor.primary or false) (
      if monitors == []
      then null
      else builtins.head monitors
    )
    monitors;
  primaryOutput =
    if primary == null
    then ""
    else primary.name;
  themeFile = pkgs.writeText "Theme.qml" ''
    pragma Singleton
    import QtQuick

    QtObject {
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "    readonly property color ${name}: ${builtins.toJSON value}") palette)}
        readonly property string fontFamily: "Atkinson Hyperlegible Next"
        readonly property string monoFamily: "IosevkaCadmus Nerd Font"
        readonly property string primaryOutput: ${builtins.toJSON primaryOutput}
        readonly property string niri: ${builtins.toJSON (lib.getExe pkgs.niri)}
        readonly property string vicinae: ${builtins.toJSON (lib.getExe pkgs.configured.vicinae)}
        readonly property string locker: ${builtins.toJSON (lib.getExe pkgs.configured.swaylock)}
        readonly property string audioMixer: ${builtins.toJSON (lib.getExe pkgs.pwvucontrol)}
    }
  '';
  source = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type: builtins.baseNameOf path != "default.nix";
  };
  configDirectory = pkgs.runCommand "laplace-desktop-shell" {} ''
    mkdir -p "$out"
    cp -R ${source}/. "$out/"
    cp ${themeFile} "$out/Theme.qml"
  '';
in
  (lib.laplace.pkgs.mkWrapper pkgs quickshell {
    set.QS_CONFIG_PATH = configDirectory;
    run = ["unset QS_CONFIG_NAME QS_MANIFEST"];
    postBuild = ''
      rm "$out/bin/qs"
      ln -s quickshell "$out/bin/qs"
    '';
  }).overrideAttrs (old: {
    passthru = (old.passthru or {}) // {inherit configDirectory themeFile;};
  })
