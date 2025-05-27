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
  dwl-bar = pkgs.writeShellScriptBin "dwl-bar" ''
    interval=0

    # load colors
    cpu() {
      cpu_val=$(grep -o "^[^ ]*" /proc/loadavg)

      printf "  ^fg(cba6f7) ^fg()"
      printf "$cpu_val"
    }

    mem() {
      printf "  ^fg(89b4fa) ^fg()"
      printf " $(free -h | awk '/^Mem/ { print $3 }' | sed s/i//g)"
    }

    clock() {
      printf "  ^fg(b4befe)󱑆 ^fg()"
      printf "$(date "+%Y-%m-%d %H:%M")"
    }

    battery() {
      printf "  ^fg(a6e3a1) ^fg()"
      get_capacity="$(cat /sys/class/power_supply/BAT1/capacity)"
      printf "$get_capacity%s" " %"
    }

    volume() {
      printf "  ^fg(eba0ac)  ^fg()"
      echo "$(echo "scale=2; $(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}') * 100" | bc  | cut -d '.' -f 1) %"
    }

    brightness() {
      printf "  ^fg(f9e2af)  ^fg()"
      echo "$(echo "scale=2; $(cat /sys/class/backlight/*/brightness) / 255 * 100" | bc | cut -d '.' -f 1) %"
    }

    DELIMITER="  ^fg(313244)|^fg()"
    while true; do
      [ $interval = 0 ] || [ $(($interval % 3600)) = 0 ]
      interval=$((interval + 1))

      sleep 1 && echo "$(volume)$DELIMITER$(brightness)$DELIMITER$(battery)$DELIMITER$(cpu)$DELIMITER$(mem)$DELIMITER$(clock)"
    done
  '';
  startup = pkgs.writeShellScriptBin "startup" ''
    if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
      eval $(dbus-launch --exit-with-session --sh-syntax)
    fi
    ## https://bbs.archlinux.org/viewtopic.php?id=224652
    # Need QT theme for syncthing tray
    systemctl import-environment --user DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS \
      QT_QPA_PLATFORMTHEME PATH XCURSOR_SIZE XCURSOR_THEME

    systemctl --user start dwl-session.target
  '';
  configuration =
    pkgs.writeText "bash.bashrc"
    # sh
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
         ${lib.getExe dwl-bar} | exec ${lib.getExe dwl} -s ${lib.getExe startup}
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
