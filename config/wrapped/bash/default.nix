{
  self,
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) writeShellScriptBin;
  inherit
    (lib)
    fold
    ;
  cacheDir = "$HOME/.cache/dwl_info";
  dwl = inputs.gungnir.packages.${pkgs.system}.dwl.override {
    enableXWayland = false;
  };
  wlr-randr = lib.getExe pkgs.wlr-randr;
  configure-monitor =
    fold (
      curr: acc:
      # sh
      ''
        ${acc}
        ${wlr-randr} --output "${curr.name}" \
          --pos ${toString curr.pos.x},${toString curr.pos.y} \
          --mode ${toString curr.width}x${toString curr.height}@${toString curr.refreshRate} 2> /dev/null
      ''
    ) ""
    config.laplace.hardware.monitors;

  autostart =
    writeShellScriptBin "autostart"
    /*
    sh
    */
    ''
      ${configure-monitor}
      ${lib.getExe pkgs.swaybg} -m fill -i ${./wallpaper.png} 2> /dev/null &
      ${yambar}/bin/yambar &
    '';

  yambar = pkgs.configured.yambar.override {inherit cacheDir;};

  configuration =
    pkgs.writeText "bash.bashrc"
    # bash
    ''
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
         dbus-update-activation-environment --systemd --all
         systemctl import-environment --user \
            DISPLAY \
            WAYLAND_DISPLAY \
            XDG_SESSION_TYPE \
            DBUS_SESSION_BUS_ADDRESS \
            QT_QPA_PLATFORMTHEME \
            PATH \
            XCURSOR_SZE \
            XCURSOR_THEME
         exec ${lib.getExe dwl} -s ${lib.getExe autostart} > ${cacheDir}
       fi
       if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
         shopt -q login_shell && LOGIN_OPTION="--login" || LOGIN_OPTION=""
         exec ${lib.getExe pkgs.configured.fish} $LOGIN_OPTION
       fi
    '';
in
  mkWrapper pkgs pkgs.bash ''
    wrapProgram $out/bin/bash \
     --add-flags '--rcfile' --add-flags '${configuration}'
  ''
