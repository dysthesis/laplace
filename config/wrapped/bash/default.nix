{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (lib.cli) toGNUCommandLineShell;
  inherit (builtins) elem;
  inherit
    (lib)
    fold
    map
    concatStringsSep
    optionalString
    ;
  isLaptop = config.networking.hostName == "phobos";
  laptopModules = [
    "brightness"
    "battery"
  ];
  mkLaptopModules = modules: modules |> map (x: "$(${x})$DELIMITER") |> concatStringsSep "";

  weather = pkgs.stdenv.mkDerivation {
    name = "weather";
    buildInputs = [
      (pkgs.python311.withPackages (pythonPackages: with pythonPackages; [ftputil]))
    ];
    unpackPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cp ${./weather.py} $out/bin/weather
      chmod +x $out/bin/weather
    '';
  };

  # fml steam needs xorg
  dwl = inputs.gungnir.packages.${pkgs.system}.dwl.override {
    enableXWayland = true;
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

      systemctl --user start dwl-session.target
    '';
  configuration = let
    # NOTE: This will only be added if the host is a desktop
    startDisplay =
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
            ${lib.getExe inputs.status.packages.${pkgs.system}.default} | exec ${lib.getExe dwl} -s ${lib.getExe startup}
        fi
      '';
  in
    pkgs.writeText "bash.bashrc"
    # sh
    ''
      ${optionalString (elem "desktop" config.laplace.profiles) startDisplay}
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
