{
  environment = {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    QT_QPA_PLATFORM = "wayland";
    GTK_USE_PORTAL = "1";
    NIXOS_OZONE_WL = "1";
    CLUTTER_BACKEND = "wayland";
  };

  cursor = {
    xcursorTheme = "Bibata-Modern-Classic";
    xcursorSize = 18;
    hideAfterInactiveMs = 1250;
  };

  input = {
    focusFollowsMouse = true;
    keyboard.numlock = true;
    mouse = {
      naturalScroll = true;
      accelSpeed = 0.2;
      accelProfile = "flat";
    };
    touchpad = {
      tap = true;
      naturalScroll = true;
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
    defaultColumnWidth.proportion = 0.5;
    focusRing = {
      width = 1.5;
      activeColor = "#ffffff";
      inactiveColor = "#0f0f0f";
    };
  };

  preferNoCsd = true;

  startup = [
    {command = "dunst";}
    {command = "waybar";}
    {
      command = "swaybg";
      args = [
        "-i"
        {ref = "wallpaper";}
        "-m"
        "fill"
      ];
    }
  ];

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
      combo = "Mod+Shift+E";
      actions = [
        {
          type = "action";
          name = "quit";
          options."skip-confirmation" = true;
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
          name = "focus-column-left";
        }
      ];
    }
    {
      combo = "Mod+L";
      actions = [
        {
          type = "action";
          name = "focus-column-right";
        }
      ];
    }
    {
      combo = "Mod+J";
      actions = [
        {
          type = "action";
          name = "focus-window-down";
        }
      ];
    }
    {
      combo = "Mod+K";
      actions = [
        {
          type = "action";
          name = "focus-window-up";
        }
      ];
    }
    {
      combo = "Mod+A";
      actions = [
        {
          type = "action";
          name = "consume-window-into-column";
        }
      ];
    }
    {
      combo = "Mod+D";
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
          name = "move-column-left";
        }
      ];
    }
    {
      combo = "Mod+Shift+L";
      actions = [
        {
          type = "action";
          name = "move-column-right";
        }
      ];
    }
    {
      combo = "Mod+Shift+J";
      actions = [
        {
          type = "action";
          name = "move-window-down";
        }
      ];
    }
    {
      combo = "Mod+Shift+K";
      actions = [
        {
          type = "action";
          name = "move-window-up";
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
      combo = "Mod+W";
      actions = [
        {
          type = "action";
          name = "toggle-column-tabbed-display";
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
      combo = "XF86AudioRaiseVolume";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn-sh";
          script = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+";
        }
      ];
    }
    {
      combo = "XF86AudioLowerVolume";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn-sh";
          script = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-";
        }
      ];
    }
    {
      combo = "XF86AudioMute";
      allowWhenLocked = true;
      actions = [
        {
          type = "spawn-sh";
          script = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
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
  ];
}
