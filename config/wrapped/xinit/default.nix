{
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) system;
  wm = getExe inputs.gungnir.packages.${system}.dwm;

  xinitrc = with pkgs;
    writeText ".xinitrc"
    # sh
    ''
      # turn off Display Power Management Service (DPMS)
      xset -dpms
      setterm -blank 0 -powerdown 0

      # turn off black Screensaver
      xset s off

      dbus-update-activation-environment --systemd --all

      # Start some services
      ${getExe syncthing} -no-browser &
      ${getExe configured.spotify_player} -d &
      ${configured.dunst}/bin/dunst &
      ${getExe udiskie} &
      ${getExe hsetroot} -cover ${./wallpaper.png} &
      ${getExe inputs.gungnir.packages.${system}.dwm-bar} &
      exec ${wm}
    '';
in
  mkWrapper pkgs pkgs.xorg.xinit ''
    wrapProgram "$out/bin/startx" --set XINITRC ${xinitrc};
  ''
