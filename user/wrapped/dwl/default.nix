{
  config,
  lib,
  inputs,
  pkgs,
  self,
  ...
}: let
  wallpaper = "${self}/user/wallpaper.png";
in
  inputs.dwl.packages.${pkgs.system}.default.override {
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
        modifiers = [
          "MODKEY"
          "WLR_MODIFIER_SHIFT"
        ];
        key = "XKB_KEY_P";
        function = "spawn";
        argument = let
          screenshot =
            pkgs.writeShellScriptBin "screenshot"
            /*
            sh
            */
            ''
              ${lib.getExe pkgs.slurp} | ${lib.getExe pkgs.grim} -g - - | ${pkgs.wl-clipboard}/bin/wl-copy
            '';
        in
          mkShCmd (lib.getExe screenshot);
        comment = "Screenshot";
      }
      {
        modifiers = [
          "MODKEY"
          "WLR_MODIFIER_SHIFT"
        ];
        key = "XKB_KEY_L";
        function = "spawn";
        argument = mkShCmd (lib.getExe pkgs.configured.swaylock);
        comment = "Lock screen";
      }
      {
        modifiers = [
          "MODKEY"
          "WLR_MODIFIER_SHIFT"
        ];
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
        modifiers = [
          "MODKEY"
          "WLR_MODIFIER_SHIFT"
        ];
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
        modifiers = [
          "MODKEY"
          "WLR_MODIFIER_SHIFT"
        ];
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
      wbgCmd = [
        (lib.getExe pkgs.wbg)
        wallpaper
      ];
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
    in [
      importEnvCmd
      wlsunsetCmd
      wbgCmd
      dunstCmd
      wlrRandrCmd
    ];
  }
