{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) elem;
  inherit (lib) optionalString;
  configuration = let
    startWayland = let
      inherit (lib.cli) toGNUCommandLineShell;
      inherit (lib) fold;
      dwl = inputs.gungnir.packages.${pkgs.system}.dwl.override {
        enableXWayland = false;
      };
      startup = let
        wlsunset = let
          args = toGNUCommandLineShell {} {
            t = "3700";
            T = "6200";
            g = "1.0";
            l = config.location.latitude;
            L = config.location.longitude;
          };
        in "${pkgs.wlsunset}/bin/wlsunset ${args} &";
        swaybg = ''
          ${lib.getExe pkgs.swaybg} -i ${./wallpaper.png} &
        '';
        dunst = "${pkgs.configured.dunst}/bin/dunst &";
        wlr-randr = let
          wlr-randr = lib.getExe pkgs.wlr-randr;
          wlr-randr-args =
            fold (
              curr: acc: "${acc} --output ${curr.name} --mode ${toString curr.width}x${toString curr.height}@${toString curr.refreshRate}Hz"
            ) ""
            config.laplace.hardware.monitors;
        in ''
          ${wlr-randr} ${wlr-randr-args}
        '';
        emacs = inputs.jormungandr.packages.${pkgs.system}.default;
      in
        pkgs.writeShellScriptBin "startup" ''
          if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
            eval $(dbus-launch --exit-with-session --sh-syntax)
          fi
          ## https://bbs.archlinux.org/viewtopic.php?id=224652
          # Need QT theme for syncthing tray
          systemctl import-environment --user DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS \
            QT_QPA_PLATFORMTHEME PATH XCURSOR_SIZE XCURSOR_THEME

          ${wlsunset}
          ${swaybg}
          ${dunst}
          ${wlr-randr}
          ${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${lib.getExe pkgs.cliphist} store &
          ${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${lib.getExe pkgs.cliphist} store &
          ${emacs}/bin/emacs --daemon

          systemctl --user start dwl-session.target
        '';
    in ''
      exec $(${lib.getExe inputs.status.packages.${pkgs.system}.default} |
        ${lib.getExe dwl} -s ${lib.getExe startup})
    '';
    startXorg = "exec ${pkgs.configured.xinit}/bin/startx";
    startDisplay =
      # sh
      ''
        if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
         ${optionalString (elem "wayland" config.laplace.display.servers) startWayland}
         ${optionalString (elem "xorg" config.laplace.display.servers) startXorg}
        fi
      '';
  in
    pkgs.writeText "bash.bashrc"
    # sh
    ''
      ${optionalString (elem "desktop" config.laplace.profiles) startDisplay}
    '';
in
  mkWrapper pkgs pkgs.bash ''
    wrapProgram $out/bin/bash \
     --add-flags '--rcfile' --add-flags '${configuration}'
  ''
