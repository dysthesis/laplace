{
  environment = {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    QT_QPA_PLATFORM = "wayland;xcb";
    GTK_USE_PORTAL = "1";
    NIXOS_OZONE_WL = "1";
    CLUTTER_BACKEND = "wayland";
  };

  cursor = {
    xcursorTheme = "Bibata-Modern-Classic";
    xcursorSize = 18;
    hideAfterInactiveMs = 1250;
    hideWhenTyping = true;
  };

  input = {
    focusFollowsMouse."max-scroll-amount" = "10%";
    workspaceAutoBackAndForth = true;
    keyboard.numlock = true;
    mouse = {
      naturalScroll = true;
      accelSpeed = 0.2;
      accelProfile = "flat";
    };
    trackball.naturalScroll = true;
    touchpad = {
      tap = true;
      dwt = true;
      naturalScroll = true;
      disabledOnExternalMouse = true;
      clickMethod = "clickfinger";
    };
  };

  screenshotPath = "~/Pictures/Screenshots/%Y-%m-%d-%H%M%S.png";

  layout = {
    gaps = 8;
    centerFocusedColumn = "on-overflow";
    alwaysCenterSingleColumn = true;
    presetColumnWidths.proportions = [
      0.33333
      0.5
      0.66667
    ];
    presetWindowHeights.proportions = [
      0.33333
      0.5
      0.66667
    ];
    defaultColumnWidth.proportion = 0.5;
    tabIndicator = {
      hideWhenSingleTab = true;
      placeWithinColumn = true;
      gap = 5;
      width = 4;
      lengthTotalProportion = 1.0;
      position = "right";
      gapsBetweenTabs = 2;
      cornerRadius = 4;
      activeColor = "#ffffff";
      inactiveColor = "#5c5c5c";
      urgentColor = "#d70000";
    };
    focusRing = {
      width = 1.5;
      activeColor = "#ffffff";
      inactiveColor = "#0f0f0f";
    };
  };

  preferNoCsd = true;

  blur = {
    passes = 3;
    offset = 3.0;
    noise = 0.02;
    saturation = 1.5;
  };

  hotkeyOverlay.hideNotBound = true;

  windowRules = [
    {
      matches = [
        {appId = "^foot$";}
      ];
      backgroundEffect.blur = true;
    }
    {
      matches = [{namespace = "^vicinae$";}];
      backgroundEffect = {
        blur = true;
        xray = false;
      };
    }
    {
      matches = [
        {title = "^Picture-in-Picture$";}
      ];
      openFloating = true;
      defaultColumnWidth.fixed = 480;
      defaultWindowHeight.fixed = 270;
      defaultFloatingPosition = {
        x = 32;
        y = 32;
        relativeTo = "bottom-right";
      };
    }
    {
      matches = [
        {appId = "^org\\.keepassxc\\.KeePassXC$";}
        {appId = "^org\\.gnome\\.World\\.Secrets$";}
      ];
      blockOutFrom = "screen-capture";
    }
    {
      matches = [
        {isFloating = true;}
      ];
      drawBorderWithBackground = false;
      geometryCornerRadius = 8;
      clipToGeometry = true;
    }
    {
      matches = [
        {appId = "^mpv$";}
      ];
      openFloating = false;
      defaultColumnWidth.proportion = 0.8;
      defaultWindowHeight.proportion = 0.8;
      variableRefreshRate = true;
    }
  ];

  startup = [];

  binds = [
    {
      combo = "Mod+Return";
      title = "Open a terminal";
      actions = [
        {
          type = "spawn";
          command = "terminal";
        }
      ];
    }
    {
      combo = "Mod+R";
      title = "Launch an application";
      actions = [
        {
          type = "spawn";
          command = "launcher";
        }
      ];
    }
    {
      combo = "Mod+Shift+Slash";
      title = "Show hotkey overlay";
      actions = [
        {
          type = "action";
          name = "show-hotkey-overlay";
        }
      ];
    }
    {
      combo = "Mod+Shift+E";
      actions = [
        {
          type = "action";
          name = "quit";
        }
      ];
    }
    {
      combo = "Mod+Q";
      actions = [
        {
          type = "action";
          name = "close-window";
        }
      ];
    }
    {
      combo = "Mod+O";
      actions = [
        {
          type = "action";
          name = "toggle-overview";
        }
      ];
    }
    {
      combo = "Mod+H";
      actions = [
        {
          type = "action";
          name = "focus-column-or-monitor-left";
        }
      ];
    }
    {
      combo = "Mod+L";
      actions = [
        {
          type = "action";
          name = "focus-column-or-monitor-right";
        }
      ];
    }
    {
      combo = "Mod+J";
      actions = [
        {
          type = "action";
          name = "focus-window-or-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+K";
      actions = [
        {
          type = "action";
          name = "focus-window-or-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+A";
      actions = [
        {
          type = "action";
          name = "consume-or-expel-window-left";
        }
      ];
    }
    {
      combo = "Mod+D";
      actions = [
        {
          type = "action";
          name = "consume-or-expel-window-right";
        }
      ];
    }
    {
      combo = "Mod+Shift+A";
      actions = [
        {
          type = "action";
          name = "consume-window-into-column";
        }
      ];
    }
    {
      combo = "Mod+Shift+D";
      actions = [
        {
          type = "action";
          name = "expel-window-from-column";
        }
      ];
    }
    {
      combo = "Mod+Shift+H";
      actions = [
        {
          type = "action";
          name = "move-column-left-or-to-monitor-left";
        }
      ];
    }
    {
      combo = "Mod+Shift+L";
      actions = [
        {
          type = "action";
          name = "move-column-right-or-to-monitor-right";
        }
      ];
    }
    {
      combo = "Mod+Shift+J";
      actions = [
        {
          type = "action";
          name = "move-window-down-or-to-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+Shift+K";
      actions = [
        {
          type = "action";
          name = "move-window-up-or-to-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+Comma";
      actions = [
        {
          type = "action";
          name = "focus-monitor-left";
        }
      ];
    }
    {
      combo = "Mod+Period";
      actions = [
        {
          type = "action";
          name = "focus-monitor-right";
        }
      ];
    }
    {
      combo = "Mod+Shift+Comma";
      actions = [
        {
          type = "action";
          name = "move-window-to-monitor-left";
        }
      ];
    }
    {
      combo = "Mod+Shift+Period";
      actions = [
        {
          type = "action";
          name = "move-window-to-monitor-right";
        }
      ];
    }
    {
      combo = "Mod+W";
      actions = [
        {
          type = "action";
          name = "toggle-column-tabbed-display";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+W";
      actions = [
        {
          type = "action";
          name = "set-column-display";
          args = ["tabbed"];
        }
      ];
    }
    {
      combo = "Mod+Ctrl+Shift+W";
      actions = [
        {
          type = "action";
          name = "set-column-display";
          args = ["normal"];
        }
      ];
    }
    {
      combo = "Mod+S";
      actions = [
        {
          type = "action";
          name = "switch-preset-column-width";
        }
      ];
    }
    {
      combo = "Mod+Shift+S";
      actions = [
        {
          type = "action";
          name = "switch-preset-column-width-back";
        }
      ];
    }
    {
      combo = "Mod+F";
      actions = [
        {
          type = "action";
          name = "maximize-column";
        }
      ];
    }
    {
      combo = "Mod+M";
      actions = [
        {
          type = "action";
          name = "maximize-window-to-edges";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+F";
      actions = [
        {
          type = "action";
          name = "expand-column-to-available-width";
        }
      ];
    }
    {
      combo = "Mod+C";
      actions = [
        {
          type = "action";
          name = "center-column";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+C";
      actions = [
        {
          type = "action";
          name = "center-visible-columns";
        }
      ];
    }
    {
      combo = "Mod+Minus";
      actions = [
        {
          type = "action";
          name = "set-column-width";
          args = ["-10%"];
        }
      ];
    }
    {
      combo = "Mod+Equal";
      actions = [
        {
          type = "action";
          name = "set-column-width";
          args = ["+10%"];
        }
      ];
    }
    {
      combo = "Mod+Shift+Minus";
      actions = [
        {
          type = "action";
          name = "set-window-height";
          args = ["-10%"];
        }
      ];
    }
    {
      combo = "Mod+Shift+Equal";
      actions = [
        {
          type = "action";
          name = "set-window-height";
          args = ["+10%"];
        }
      ];
    }
    {
      combo = "Mod+Ctrl+R";
      actions = [
        {
          type = "action";
          name = "reset-window-height";
        }
      ];
    }
    {
      combo = "Mod+V";
      actions = [
        {
          type = "action";
          name = "toggle-window-floating";
        }
      ];
    }
    {
      combo = "Mod+Shift+V";
      actions = [
        {
          type = "action";
          name = "switch-focus-between-floating-and-tiling";
        }
      ];
    }
    {
      combo = "Mod+Shift+F";
      actions = [
        {
          type = "action";
          name = "fullscreen-window";
        }
      ];
    }
    {
      combo = "Mod+Page_Down";
      actions = [
        {
          type = "action";
          name = "focus-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+Page_Up";
      actions = [
        {
          type = "action";
          name = "focus-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+Page_Down";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+Page_Up";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+Alt+Page_Down";
      actions = [
        {
          type = "action";
          name = "move-window-to-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+Alt+Page_Up";
      actions = [
        {
          type = "action";
          name = "move-window-to-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+1";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [1];
        }
      ];
    }
    {
      combo = "Mod+2";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [2];
        }
      ];
    }
    {
      combo = "Mod+3";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [3];
        }
      ];
    }
    {
      combo = "Mod+4";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [4];
        }
      ];
    }
    {
      combo = "Mod+5";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [5];
        }
      ];
    }
    {
      combo = "Mod+6";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [6];
        }
      ];
    }
    {
      combo = "Mod+7";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [7];
        }
      ];
    }
    {
      combo = "Mod+8";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [8];
        }
      ];
    }
    {
      combo = "Mod+9";
      actions = [
        {
          type = "action";
          name = "focus-workspace";
          args = [9];
        }
      ];
    }
    {
      combo = "Mod+Shift+1";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [1];
        }
      ];
    }
    {
      combo = "Mod+Shift+2";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [2];
        }
      ];
    }
    {
      combo = "Mod+Shift+3";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [3];
        }
      ];
    }
    {
      combo = "Mod+Shift+4";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [4];
        }
      ];
    }
    {
      combo = "Mod+Shift+5";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [5];
        }
      ];
    }
    {
      combo = "Mod+Shift+6";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [6];
        }
      ];
    }
    {
      combo = "Mod+Shift+7";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [7];
        }
      ];
    }
    {
      combo = "Mod+Shift+8";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [8];
        }
      ];
    }
    {
      combo = "Mod+Shift+9";
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace";
          args = [9];
        }
      ];
    }
    {
      combo = "Mod+WheelScrollDown";
      cooldownMs = 150;
      actions = [
        {
          type = "action";
          name = "focus-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+WheelScrollUp";
      cooldownMs = 150;
      actions = [
        {
          type = "action";
          name = "focus-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+WheelScrollDown";
      cooldownMs = 150;
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace-down";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+WheelScrollUp";
      cooldownMs = 150;
      actions = [
        {
          type = "action";
          name = "move-column-to-workspace-up";
        }
      ];
    }
    {
      combo = "Mod+WheelScrollRight";
      actions = [
        {
          type = "action";
          name = "focus-column-right";
        }
      ];
    }
    {
      combo = "Mod+WheelScrollLeft";
      actions = [
        {
          type = "action";
          name = "focus-column-left";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+WheelScrollRight";
      actions = [
        {
          type = "action";
          name = "move-column-right";
        }
      ];
    }
    {
      combo = "Mod+Ctrl+WheelScrollLeft";
      actions = [
        {
          type = "action";
          name = "move-column-left";
        }
      ];
    }
    {
      combo = "Mod+Escape";
      allowInhibiting = false;
      actions = [
        {
          type = "action";
          name = "toggle-keyboard-shortcuts-inhibit";
        }
      ];
    }
    {
      combo = "Mod+Shift+P";
      actions = [
        {
          type = "action";
          name = "power-off-monitors";
        }
      ];
    }
    {
      combo = "XF86AudioRaiseVolume";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn";
          command = "wpctl";
          args = [
            "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "0.05+"
          ];
        }
      ];
    }
    {
      combo = "XF86AudioLowerVolume";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn";
          command = "wpctl";
          args = [
            "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "0.05-"
          ];
        }
      ];
    }
    {
      combo = "XF86AudioMute";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn";
          command = "wpctl";
          args = [
            "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle"
          ];
        }
      ];
    }
    {
      combo = "XF86MonBrightnessUp";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn";
          command = "brightnessctl";
          args = [
            "--class=backlight"
            "set"
            "+5%"
          ];
        }
      ];
    }
    {
      combo = "XF86MonBrightnessDown";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn";
          command = "brightnessctl";
          args = [
            "--class=backlight"
            "set"
            "5%-"
          ];
        }
      ];
    }
    {
      combo = "Print";
      actions = [
        {
          type = "action";
          name = "screenshot";
        }
      ];
    }
    {
      combo = "Mod+P";
      actions = [
        {
          type = "action";
          name = "screenshot-screen";
        }
      ];
    }
    {
      combo = "Mod+Shift+Tab";
      actions = [
        {
          type = "action";
          name = "move-workspace-to-monitor-left";
        }
      ];
    }
    {
      combo = "Alt+Print";
      actions = [
        {
          type = "action";
          name = "screenshot-window";
        }
      ];
    }
  ];
}
