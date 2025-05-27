{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  dwl = inputs.gungnir.packages.${pkgs.system}.dwl.override {
    enableXWayland = false;
  };
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
       systemctl --user start dwl-session.target
       exec ${lib.getExe dwl} &

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
