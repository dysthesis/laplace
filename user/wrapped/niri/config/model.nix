{lib, ...}: let
  data = import ./data.nix;
  transforms = import ./transforms.nix {inherit lib;};
  spawnBind = combo: title: command: args: {
    inherit combo title;
    repeat = false;
    actions = [
      {
        type = "spawn";
        inherit command args;
      }
    ];
  };
  actionBind = combo: title: name: {
    inherit combo title;
    repeat = false;
    actions = [
      {
        type = "action";
        inherit name;
      }
    ];
  };
  noctaliaBind = combo: title: args:
    spawnBind combo title "noctalia" (["msg"] ++ args);
  # Show key combinations without hardware labels in the overlay.
  hardwareBind = combo: repeat: args:
    (noctaliaBind combo null args)
    // {
      inherit repeat;
      allowWhenLocked = true;
    };
in {
  mkModel = context: let
    desktop = context.desktop or {enable = false;};
    palette = desktop.palette;
    desktopBinds = {
      "Mod+R" = spawnBind "Mod+R" null "launcher" ["toggle"];
      "Mod+Shift+E" = noctaliaBind "Mod+Shift+E" "Session menu" ["panel-toggle" "session"];
      "Mod+Shift+Tab" = actionBind "Mod+Ctrl+Comma" "Move workspace to left monitor" "move-workspace-to-monitor-left";
      "XF86AudioRaiseVolume" = hardwareBind "XF86AudioRaiseVolume" true ["volume-up" "5"];
      "XF86AudioLowerVolume" = hardwareBind "XF86AudioLowerVolume" true ["volume-down" "5"];
      "XF86AudioMute" = hardwareBind "XF86AudioMute" false ["volume-mute"];
      "XF86MonBrightnessUp" = hardwareBind "XF86MonBrightnessUp" true ["brightness-up" "all" "5%"];
      "XF86MonBrightnessDown" = hardwareBind "XF86MonBrightnessDown" true ["brightness-down" "all" "5%"];
    };
    desktopTitles = {
      "Mod+H" = "Focus left";
      "Mod+J" = "Focus down";
      "Mod+K" = "Focus up";
      "Mod+L" = "Focus right";
      "Mod+Shift+H" = "Move window/column with H/J/K/L";
      "Mod+Comma" = "Focus monitor with , / .";
      "Mod+Shift+Comma" = "Move window to monitor with , / .";
      "Mod+1" = "Workspace 1-9 (Shift moves column)";
      "Mod+WheelScrollLeft" = null;
      "Mod+WheelScrollRight" = null;
      "Mod+Ctrl+WheelScrollLeft" = null;
      "Mod+Ctrl+WheelScrollRight" = null;
    };
    settings =
      if !desktop.enable
      then data
      else
        data
        // {
          cursor =
            data.cursor
            // {
              xcursorSize = 24;
              hideAfterInactiveMs = 3000;
            };
          input =
            data.input
            // {
              focusFollowsMouse = data.input.focusFollowsMouse // {"max-scroll-amount" = "0%";};
              workspaceAutoBackAndForth = false;
            };
          hotkeyOverlay = data.hotkeyOverlay // {skipAtStartup = true;};
          layout =
            data.layout
            // {
              gaps = 10;
              focusRing = {
                width = 2;
                activeColour = palette.focus;
                inactiveColour = palette.border;
              };
              tabIndicator =
                data.layout.tabIndicator
                // {
                  activeColour = palette.focus;
                  inactiveColour = palette.border;
                  urgentColour = palette.urgent;
                };
            };
          windowRules =
            lib.filter (
              rule:
                !(lib.any (match: (match.appId or null) == "^foot$") (rule.matches or [])
                  && (rule.backgroundEffect.blur or false))
            )
            data.windowRules;
          binds =
            map (
              bind:
                if bind.combo == "Mod+V"
                then bind // {combo = "Mod+Ctrl+V";}
                else if desktopTitles ? ${bind.combo}
                then bind // {title = desktopTitles.${bind.combo};}
                else desktopBinds.${bind.combo} or bind
            )
            data.binds
            ++ [
              (spawnBind "Mod+Space" "Launch an application" "launcher" ["toggle"])
              (spawnBind "Mod+V" "Clipboard history" "launcher" ["vicinae://launch/clipboard/history"])
              (noctaliaBind "Mod+N" "Notifications" ["panel-toggle" "control-center" "notifications"])
              (noctaliaBind "Mod+Shift+N" "Toggle do not disturb" ["notification-dnd-toggle"])
              (noctaliaBind "Mod+Ctrl+Space" "Control centre" ["panel-toggle" "control-center" "home"])
              (actionBind "Alt+Tab" "Focus previous window" "focus-window-previous")
              (actionBind "Mod+Tab" "Focus previous workspace" "focus-workspace-previous")
              (actionBind "Mod+Ctrl+Period" "Move workspace to right monitor" "move-workspace-to-monitor-right")
              (hardwareBind "XF86AudioMicMute" false ["mic-mute"])
              (hardwareBind "XF86AudioPlay" false ["media" "toggle"])
              (hardwareBind "XF86AudioPause" false ["media" "pause"])
              (hardwareBind "XF86AudioNext" false ["media" "next"])
              (hardwareBind "XF86AudioPrev" false ["media" "previous"])
            ];
        };
    binds = map (transforms.resolveBind context.deps) settings.binds;
    outputs = map transforms.monitorToOutput context.monitors;
  in
    transforms.validateModel {
      inherit binds outputs;
      inherit
        (settings)
        environment
        cursor
        input
        screenshotPath
        layout
        preferNoCsd
        blur
        hotkeyOverlay
        windowRules
        ;
      xwaylandSatellite = context.deps.xwaylandSatellite;
    };
}
