{
  pkgs,
  lib,
  config,
  inputs ? { },
  ...
}:
let
  KDL = import ./kdl.nix { inherit lib; };

  location = {
    latitude = lib.attrByPath [ "location" "latitude" ] 0 config;
    longitude = lib.attrByPath [ "location" "longitude" ] 0 config;
  };

  monitors = lib.attrByPath [ "laplace" "hardware" "monitors" ] [ ] config;

  wallpaper = ../hyprland/config/wallpaper.png;

  terminalCmd = lib.getExe pkgs.configured.ghostty;
  launcherCmd = "${pkgs.configured.bemenu}/bin/bemenu-run";
  lockerCmd = lib.getExe pkgs.configured.swaylock;

  spawnCommand =
    executable: args:
    [ executable ] ++ args;

  spawnAtStartup =
    map (
      cmdArgs:
      KDL.statement {
        name = "spawn-at-startup";
        args = cmdArgs;
      }
    ) (
      [
        (spawnCommand (lib.getExe pkgs.configured.dunst) [ ])
        (spawnCommand (lib.getExe pkgs.configured.waybar) [ ])
        (spawnCommand (lib.getExe pkgs.swaybg) [
          "-i"
          wallpaper
          "-m"
          "fill"
        ])
      ]
      ++ lib.optionals ((location.latitude != 0) || (location.longitude != 0)) [
        (spawnCommand (lib.getExe pkgs.wlsunset) [
          "-t"
          "3700"
          "-T"
          "6200"
          "-g"
          "1.0"
          "-l"
          (toString location.latitude)
          "-L"
          (toString location.longitude)
        ])
      ]
    );

  mkInlineAction =
    { name, args ? [ ], assign ? { } }:
    {
      inherit name args assign;
      inline = true;
    };

  mkSpawn =
    { command, extraArgs ? [ ], assign ? { } }:
    mkInlineAction {
      name = "spawn";
      args = [ command ] ++ extraArgs;
      inherit assign;
    };

  mkSpawnSh =
    script:
    mkInlineAction {
      name = "spawn-sh";
      args = [ script ];
    };

  mkBind =
    { combo, actions, assign ? { }, comment ? null }:
    {
      name = combo;
      inline = false;
      children = actions;
      assign = assign;
      inherit comment;
    };

  bindActions = [
    (mkBind {
      combo = "Mod+Return";
      actions = [
        (mkSpawn {
          command = terminalCmd;
          assign = {
            "hotkey-overlay-title" = "Open a terminal";
          };
        })
      ];
    })
    (mkBind {
      combo = "Mod+D";
      actions = [
        (mkSpawn {
          command = launcherCmd;
          assign = {
            "hotkey-overlay-title" = "Launch an application";
          };
        })
      ];
    })
    (mkBind {
      combo = "Super+Alt+L";
      actions = [
        (mkSpawn {
          command = lockerCmd;
          assign = {
            "hotkey-overlay-title" = "Lock the screen";
          };
        })
      ];
    })
    (mkBind {
      combo = "Mod+Shift+E";
      actions = [
        (mkInlineAction {
          name = "quit";
          assign = { "skip-confirmation" = true; };
        })
      ];
    })
    (mkBind {
      combo = "Mod+Q";
      actions = [
        (mkInlineAction { name = "close-window"; })
      ];
    })
    (mkBind {
      combo = "Mod+O";
      actions = [
        (mkInlineAction { name = "toggle-overview"; })
      ];
    })
    (mkBind {
      combo = "Mod+H";
      actions = [
        (mkInlineAction { name = "focus-column-left"; })
      ];
    })
    (mkBind {
      combo = "Mod+L";
      actions = [
        (mkInlineAction { name = "focus-column-right"; })
      ];
    })
    (mkBind {
      combo = "Mod+J";
      actions = [
        (mkInlineAction { name = "focus-window-down"; })
      ];
    })
    (mkBind {
      combo = "Mod+K";
      actions = [
        (mkInlineAction { name = "focus-window-up"; })
      ];
    })
    (mkBind {
      combo = "Mod+Page_Down";
      actions = [
        (mkInlineAction { name = "focus-workspace-down"; })
      ];
    })
    (mkBind {
      combo = "Mod+Page_Up";
      actions = [
        (mkInlineAction { name = "focus-workspace-up"; })
      ];
    })
    (mkBind {
      combo = "XF86AudioRaiseVolume";
      assign = { "allow-when-locked" = true; };
      actions = [ (mkSpawnSh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+") ];
    })
    (mkBind {
      combo = "XF86AudioLowerVolume";
      assign = { "allow-when-locked" = true; };
      actions = [ (mkSpawnSh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-") ];
    })
    (mkBind {
      combo = "XF86AudioMute";
      assign = { "allow-when-locked" = true; };
      actions = [ (mkSpawnSh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") ];
    })
    (mkBind {
      combo = "XF86MonBrightnessUp";
      assign = { "allow-when-locked" = true; };
      actions = [
        (mkSpawn {
          command = lib.getExe pkgs.brightnessctl;
          extraArgs = [
            "--class=backlight"
            "set"
            "+5%"
          ];
        })
      ];
    })
    (mkBind {
      combo = "XF86MonBrightnessDown";
      assign = { "allow-when-locked" = true; };
      actions = [
        (mkSpawn {
          command = lib.getExe pkgs.brightnessctl;
          extraArgs = [
            "--class=backlight"
            "set"
            "5%-"
          ];
        })
      ];
    })
    (mkBind {
      combo = "Print";
      actions = [
        (mkInlineAction { name = "screenshot"; })
      ];
    })
  ];

  formatMode =
    monitor:
    let
      base = "${toString monitor.width}x${toString monitor.height}";
      suffix =
        if monitor ? refreshRate && monitor.refreshRate != null then
          "@${toString monitor.refreshRate}"
        else
          "";
    in
    base + suffix;

  mkOutput =
    monitor:
    let
      name =
        if monitor ? name then
          monitor.name
        else if monitor ? connector then
          monitor.connector
        else
          "eDP-1";
      body =
        {
          mode = formatMode monitor;
        }
        // lib.optionalAttrs (monitor ? scale) {
          scale = monitor.scale;
        }
        // lib.optionalAttrs (
          monitor ? pos
          && monitor.pos ? x
          && monitor.pos.x != null
          && monitor.pos ? y
          && monitor.pos.y != null
        ) {
          position = {
            inline = true;
            assign = {
              x = monitor.pos.x;
              y = monitor.pos.y;
            };
          };
        }
        // lib.optionalAttrs (monitor ? variableRefreshRate && monitor.variableRefreshRate) {
          "variable-refresh-rate" = true;
        }
        // lib.optionalAttrs (monitor ? primary && monitor.primary) {
          "focus-at-startup" = true;
        };
    in
    {
      name = "output";
      args = [ name ];
      body = body;
    };

  outputs = map mkOutput monitors;

  configTree =
    [
      (KDL.block {
        name = "environment";
        body = {
          "XDG_CURRENT_DESKTOP" = "niri";
          "XDG_SESSION_TYPE" = "wayland";
          "QT_QPA_PLATFORM" = "wayland";
          "GTK_USE_PORTAL" = "1";
          "NIXOS_OZONE_WL" = "1";
          "CLUTTER_BACKEND" = "wayland";
        };
      })
      (KDL.block {
        name = "cursor";
        body = {
          "xcursor-theme" = "Bibata-Modern-Classic";
          "xcursor-size" = 28;
          "hide-after-inactive-ms" = 1250;
        };
      })
      (KDL.block {
        name = "input";
        body = {
          keyboard = {
            numlock = true;
          };
          touchpad = {
            tap = true;
            "natural-scroll" = true;
            "click-method" = {
              inline = true;
              args = [ "clickfinger" ];
            };
          };
        };
      })
      (KDL.statement {
        name = "screenshot-path";
        args = [ "~/Pictures/Screenshots/%Y-%m-%d-%H%M%S.png" ];
      })
      (KDL.block {
        name = "layout";
        body =
          {
            gaps = 12;
            "center-focused-column" = "on-overflow";
            "always-center-single-column" = true;
            "preset-column-widths" = {
              body = {
                proportion = [
                  0.33333
                  0.5
                  0.66667
                ];
              };
            };
            "default-column-width" = {
              body = { proportion = 0.5; };
            };
            "focus-ring" = {
              body = {
                width = 4;
                "active-color" = "#7fc8ff";
                "inactive-color" = "#4c566a";
              };
            };
          };
      })
      (KDL.statement { name = "prefer-no-csd"; })
      (KDL.block {
        name = "xwayland-satellite";
        body = {
          path = lib.getExe pkgs.xwayland-satellite;
        };
      })
      (KDL.block {
        name = "binds";
        children = bindActions;
      })
    ]
    ++ outputs
    ++ spawnAtStartup;

  serialized = KDL.render configTree;
in
pkgs.writeText "niri-config.kdl" serialized
