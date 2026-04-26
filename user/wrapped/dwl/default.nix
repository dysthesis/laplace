{
  config,
  lib,
  inputs,
  pkgs,
  self,
  terminal ? {
    package = pkgs.configured.foot;
    appId = "foot";
  },
  ...
}: let
  wallpaper = "${self}/user/wallpaper.png";
  system = pkgs.stdenv.hostPlatform.system;
  baseSpec = import "${inputs.dwl}/nix/config/spec.nix";
  configSpec =
    baseSpec
    // {
      terminal = {
        argv = [(lib.getExe terminal.package)];
        inherit (terminal) appId;
      };
      swallowTerminals = [terminal.appId];
      rules = [
        {
          id = terminal.appId;
          isterm = true;
        }
        {
          id = "zen";
          tags = [0];
        }
        {
          id = "vesktop";
          tags = [2];
        }
        {
          id = "mpv";
          tags = [3];
        }
        {
          id = "${terminal.appId}.capture";
          isfloating = true;
        }
        {
          id = "${terminal.appId}.journal";
          isfloating = true;
        }
      ];
      scratchpads = let
        termExe = lib.getExe terminal.package;
      in [
        {
          name = "termscratch";
          key = "t";
          keysym = "XKB_KEY_t";
          id = "${terminal.appId}.term";
          isterm = true;
          argv = [termExe "--app-id=${terminal.appId}.term" "--title=Terminal"];
        }
        {
          name = "btopscratch";
          key = "b";
          keysym = "XKB_KEY_b";
          id = "${terminal.appId}.btop";
          isterm = true;
          argv = [termExe "--app-id=${terminal.appId}.btop" "--title=Btop" "-e" "btop"];
        }
        {
          name = "musicscratch";
          key = "m";
          keysym = "XKB_KEY_m";
          id = "${terminal.appId}.music";
          isterm = true;
          argv = [
            termExe
            "--app-id=${terminal.appId}.music"
            "--title=Music"
            "-e"
            "spotify_player"
          ];
        }
        {
          name = "notescratch";
          key = "n";
          keysym = "XKB_KEY_n";
          id = "${terminal.appId}.note";
          isterm = true;
          argv = [
            termExe
            "--app-id=${terminal.appId}.note"
            "--title=Notes"
            "-e"
            "tmux"
            "new-session"
            "-As"
            "Notes"
            "-c"
            "/home/demiurge/Documents/Notes/Contents"
            "direnv"
            "exec"
            "."
            "nvim"
          ];
        }
        {
          name = "ircscratch";
          key = "i";
          keysym = "XKB_KEY_i";
          id = "${terminal.appId}.irc";
          isterm = true;
          argv = [
            termExe
            "--app-id=${terminal.appId}.irc"
            "--title=IRC"
            "-e"
            "tmux"
            "new-session"
            "-As"
            "IRC"
            "irssi"
          ];
        }
        {
          name = "taskscratch";
          key = "d";
          keysym = "XKB_KEY_d";
          id = "${terminal.appId}.task";
          isterm = true;
          argv = [termExe "--app-id=${terminal.appId}.task" "--title=Task" "-e" "taskwarrior-tui"];
        }
        {
          name = "signalscratch";
          key = "s";
          keysym = "XKB_KEY_s";
          id = "signal";
          argv = ["signal-desktop"];
        }
      ];
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
              inherit (pkgs.configured) zk foot bemenu;
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
              inherit (pkgs.configured) bemenu zk foot;
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
              inherit (pkgs.configured) foot zk;
              neovim = inputs.poincare.packages.${system}.default;
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
              inherit (pkgs.configured) foot zk;
              neovim = inputs.poincare.packages.${system}.default;
            };
          in
            mkShCmd (lib.getExe zk-journal);
          comment = "Capture journal";
        }
        {
          modifiers = ["MODKEY"];
          key = "XKB_KEY_Return";
          function = "spawn";
          argument = mkShCmd (lib.getExe terminal.package);
          comment = "Terminal";
        }
        {
          modifiers = ["MODKEY"];
          key = "XKB_KEY_i";
          function = "incnmaster";
          argument = {
            union = "i";
            value = "+1";
          };
          comment = "Increase number of master clients";
        }
        {
          modifiers = ["MODKEY"];
          key = "XKB_KEY_d";
          function = "incnmaster";
          argument = {
            union = "i";
            value = "-1";
          };
          comment = "Decrease number of master clients";
        }
      ];
    };
in
  inputs.dwl.packages.${system}.default.override {
    enableXWayland = true;
    extraPathPackages = with pkgs; [
      configured.tmux
      configured.zk
      configured.foot
      terminal.package
      inputs.poincare.packages.${system}.default
    ];
    inherit configSpec;
    autostart = let
      # Build wlr-randr argument list from configured monitors.
      # Preserve source order and forward explicit positions so wlroots doesn't
      # fall back to auto-layout.
      wlrRandrArgs = builtins.concatLists (
        map (
          curr:
            [
              "--output"
              curr.name
            ]
            ++ lib.optionals curr.enabled [
              "--on"
              "--mode"
              "${toString curr.width}x${toString curr.height}@${toString
                curr.refreshRate}Hz"
            ]
            ++ lib.optionals (
              curr.enabled && curr.pos.x != null && curr.pos.y != null
            ) [
              "--pos"
              "${toString curr.pos.x},${toString curr.pos.y}"
            ]
            ++ lib.optionals (!curr.enabled) ["--off"]
        )
        config.laplace.hardware.monitors
      );
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
