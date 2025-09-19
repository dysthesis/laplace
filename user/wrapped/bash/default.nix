{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) elem;
  inherit (lib) optionalString;
  dwl = inputs.dwl.packages.${pkgs.system}.default.override {
    enableXWayland = true;
    extraKeybinds = let
      mkShCmd = cmd: {
        union = "v";
        argv = [
          (lib.getExe pkgs.bash)
          "-c"
          cmd
        ];
      };
    in [
      {
        modifiers = ["MODKEY" "WLR_MODIFIER_SHIFT"];
        key = "XKB_KEY_N";
        function = "spawn";
        argument = let
          bemenu-zk = pkgs.scripts.bemenu-zk.override {
            inherit (pkgs.configured) zk ghostty bemenu;
          };
        in
          mkShCmd (lib.getExe bemenu-zk);

        comment = "Launch notes picker";
      }
    ];
    autostart = let
      inherit (lib) fold;
      # Build wlr-randr argument list from configured monitors
      wlrRandrArgs =
        fold (
          curr: acc:
            acc
            ++ [
              "--output"
              curr.name
              "--mode"
              "${toString curr.width}x${toString curr.height}@${toString curr.refreshRate}Hz"
            ]
        ) []
        config.laplace.hardware.monitors;
      # Command vectors (argv)
      wlsunsetCmd = [
        "${pkgs.wlsunset}/bin/wlsunset"
        "-t"
        "3700"
        "-T"
        "6200"
        "-g"
        "1.0"
        "-l"
        "${toString config.location.latitude}"
        "-L"
        "${toString config.location.longitude}"
      ];
      wbgCmd = [(lib.getExe pkgs.wbg) "${./wallpaper.png}"];
      dunstCmd = ["${pkgs.configured.dunst}/bin/dunst"];
      wlrRandrCmd = [(lib.getExe pkgs.wlr-randr)] ++ wlrRandrArgs;
      # yambarCmd = [(lib.getExe pkgs.configured.yambar)];
      importEnvCmd = [
        "systemctl"
        "import-environment"
        "--user"
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "DBUS_SESSION_BUS_ADDRESS"
        "QT_QPA_PLATFORMTHEME"
        "PATH"
        "XCURSOR_SIZE"
        "XCURSOR_THEME"
      ];
    in [importEnvCmd wlsunsetCmd wbgCmd dunstCmd wlrRandrCmd];
  };
  configuration = let
    startWayland = ''
      exec $(${lib.getExe inputs.status.packages.${pkgs.system}.default} | ${lib.getExe dwl})
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
