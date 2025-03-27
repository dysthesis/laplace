{
  self,
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit
    (lib)
    fold
    ;
  cacheDir = "/home/demiurge/.cache/dwl_info";
  configH = inputs.gungnir.packages.${pkgs.system}.dwl-config.override {
    inherit autostart;
  };
  dwl = inputs.gungnir.packages.${pkgs.system}.dwl.override {
    enableXWayland = false;
    inherit configH;
  };
  wlr-randr = lib.getExe pkgs.wlr-randr;
  wlr-randr-args = fold (curr: acc: "${acc} --output ${curr.name} --pos ${toString curr.pos.x},${toString curr.pos.y} --mode ${toString curr.width}x${toString curr.height}@${toString curr.refreshRate}Hz") "" config.laplace.hardware.monitors;

  autostart =
    /*
    sh
    */
    ''
      "sh", "-c", "${wlr-randr} ${wlr-randr-args}", NULL,
      "sh", "-c", "${lib.getExe pkgs.swaybg} -m fill -i ${./wallpaper.png} 2>/dev/null &", NULL,
      "${yambar}/bin/yambar", "&", NULL,
      "${pkgs.configured.dunst}/bin/dunst", "&", NULL,
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
         exec ${lib.getExe dwl} > ${cacheDir}
       fi
       if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
         shopt -q login_shell && LOGIN_OPTION="--login" || LOGIN_OPTION=""
         exec ${lib.getExe pkgs.configured.fish} $LOGIN_OPTION
       fi
    '';
in
  mkWrapper
  pkgs
  pkgs.bash ''
    wrapProgram $out/bin/bash \
     --add-flags '--rcfile' --add-flags '${configuration}'
  ''
