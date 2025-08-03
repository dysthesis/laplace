{
  inputs,
  pkgs,
  lib,
  xinit,
  ...
}: let
  inherit (lib) getExe;
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) system;

  inherit (inputs.mandelbrot.packages.${pkgs.system}) xmonad;

  xinitrc = with pkgs;
    writeText ".xinitrc"
    # sh
    ''
      # turn off Display Power Management Service (DPMS)
      xset -dpms
      setterm -blank 0 -powerdown 0

      xset s off

      dbus-update-activation-environment --systemd --all

      # Start some services
      ${getExe syncthing} -no-browser &
      ${getExe configured.spotify-player} -d &
      ${configured.dunst}/bin/dunst &
      ${getExe udiskie} &
      ${getExe hsetroot} -cover ${./wallpaper.png} &
      ${inputs.mandelbrot.packages.${system}.xmobar} &
      ${getExe picom} --backend "glx" --blur-method "dual_kawase" --blur-strength 3 &
      ${getExe networkmanagerapplet} &
      systemctl import-environment --user DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS \
        QT_QPA_PLATFORMTHEME PATH XCURSOR_SIZE XCURSOR_THEME


      exec ${xmonad}/bin/xmonad-configured
    '';
in
  mkWrapper pkgs xinit ''
    wrapProgram "$out/bin/startx" --set XINITRC ${xinitrc} --prefix PATH ":" "${
      lib.makeBinPath [inputs.mandelbrot.packages.${pkgs.system}.xmobar xinit]
    }";
  ''
