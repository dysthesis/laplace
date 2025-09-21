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
      mkCmd = argv: {
        union = "v";
        inherit argv;
      };
    in [
      {
        modifiers = ["MODKEY" "WLR_MODIFIER_SHIFT"];
        key = "XKB_KEY_L";
        function = "spawn";
        argument = mkCmd [
          (lib.getExe pkgs.swaylock-effects)

          "--clock"

          "--effect-blur"
          "7x5"

          "--font"
          "JBMono Nerd Font"

          "--effect-vignette"
          "0.5:0.5"

          "-i"
          "${../bash/wallpaper.png}"

          "--indicator"
          "--indicator-radius"
          "100"
          "--indicator-thickness"
          "7"
          "--effect-blur"
          "7x5"
          "--effect-vignette"
          "0.35:0.35"

          "--inside-color"
          "080808cc"
          "--inside-ver-color"
          "708090cc"
          "--inside-wrong-color"
          "d70000cc"
          "--inside-clear-color"
          "2a2a2acc"

          "--ring-color"
          "7a7a7a"
          "--ring-ver-color"
          "7788aa"
          "--ring-wrong-color"
          "d70000"
          "--ring-clear-color"
          "ffaa88"

          "--text-color"
          "fffffff"
          "--text-ver-color"
          "7788aa"
          "--text-wrong-color"
          "d70000"
          "--text-clear-color"
          "ffaa88"

          "--key-hl-color"
          "789978"
          "--bs-hl-color"
          "d70000"

          "--line-color"
          "00000000"
          "--line-ver-color"
          "00000000"
          "--line-wrong-color"
          "00000000"
          "--line-clear-color"
          "00000000"
          "--separator-color"
          "0000000"
        ];

        comment = "Lock screen";
      }
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
      {
        modifiers = ["MODKEY"];
        key = "XKB_KEY_p";
        function = "spawn";
        argument = let
          bemenu-sys = pkgs.scripts.bemenu-sys.override {inherit (pkgs.configured) bemenu;};
        in
          mkShCmd (lib.getExe bemenu-sys);

        comment = "Open power menu";
      }
      {
        modifiers = ["MODKEY" "WLR_MODIFIER_SHIFT"];
        key = "XKB_KEY_B";
        function = "spawn";
        argument = let
          bemenu-bib = pkgs.scripts.bemenu-bib.override {
            inherit (pkgs.configured) bemenu zk ghostty;
          };
        in
          mkShCmd (lib.getExe bemenu-bib);

        comment = "Open bibliography";
      }
      {
        modifiers = ["MODKEY"];
        key = "XKB_KEY_c";
        function = "spawn";
        argument = let
          zk-capture = pkgs.scripts.zk-capture.override {
            inherit (pkgs.configured) ghostty zk;
            neovim = inputs.poincare.packages.${pkgs.system}.default;
          };
        in
          mkShCmd (lib.getExe zk-capture);
        comment = "Capture note";
      }
      {
        modifiers = ["MODKEY" "WLR_MODIFIER_SHIFT"];
        key = "XKB_KEY_D";
        function = "spawn";
        argument = let
          zk-journal = pkgs.scripts.zk-journal.override {
            inherit (pkgs.configured) ghostty zk;
            neovim = inputs.poincare.packages.${pkgs.system}.default;
          };
        in
          mkShCmd (lib.getExe zk-journal);
        comment = "Capture journal";
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
