{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) system;
  inherit
    (builtins)
    elemAt
    length
    ;
  fontSize =
    if config.networking.hostName == "phobos"
    then 15
    else 12;
  dwm = getExe (
    inputs.gungnir.packages.${system}.dwm {
      inherit fontSize;
      scratchpads = let
        inherit (lib.babel.int) scale;

        scratchpadScale = 0.8;
        cfg = config.laplace.hardware.monitors;
        monitor = elemAt cfg (length cfg - 1);

        floatpos = "50% 50% ${toString (scale monitor.width scratchpadScale)}W ${toString (scale monitor.height scratchpadScale)}H";
      in [
        rec {
          name = "term";
          class = name;
          isTerm = 1;
          cmd = [
            "st"
            "-n"
            "${class}"
          ];
          tag = 0;
          inherit floatpos;
          key = "t";
        }
        rec {
          name = "btop";
          class = name;
          isTerm = 1;
          cmd = [
            "st"
            "-n"
            "${class}"
            "-e"
            "btop"
          ];
          tag = 1;
          inherit floatpos;
          key = "b";
        }
        rec {
          name = "task";
          class = name;
          isTerm = 1;
          cmd = [
            "st"
            "-n"
            "${class}"
            "-e"
            "taskwarrior-tui"
          ];
          tag = 2;
          inherit floatpos;
          key = "d";
        }
        rec {
          name = "spotify";
          class = name;
          isTerm = 1;
          cmd = [
            "st"
            "-n"
            "${class}"
            "-e"
            "spotify_player"
          ];
          tag = 3;
          inherit floatpos;
          key = "m";
        }
        rec {
          name = "notes";
          class = name;
          isTerm = 1;
          cmd = [
            "st"
            "-n"
            "${class}"
            "-e"
            "sh"
            "-c"
            "tmux new-session -As Notes -c ~/Documents/Notes/Contents 'direnv exec . nvim'"
          ];
          tag = 4;
          inherit floatpos;
          key = "n";
        }
        {
          name = "signal_desktop";
          class = "signal";
          isTerm = 0;
          cmd = [
            "signal-desktop"
          ];
          tag = 5;
          inherit floatpos;
          key = "s";
        }
      ];
    }
  );

  inherit (inputs.mandelbrot.packages.${pkgs.system}) xmonad;

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
      ${inputs.mandelbrot.packages.${system}.xmobar}

      exec ${xmonad}/bin/xmonad-configured
    '';
in
  mkWrapper pkgs pkgs.xorg.xinit ''
    wrapProgram "$out/bin/startx" --set XINITRC ${xinitrc} --prefix PATH ":" "${lib.makeBinPath [inputs.mandelbrot.packages.${pkgs.system}.xmobar]}";
  ''
