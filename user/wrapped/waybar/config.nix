{
  config,
  lib,
  pkgs,
  ...
}: {
  bar = {
    layer = "top";
    position = "bottom";
    mode = "dock";
    exclusive = true;
    passthrough = false;
    gtkLayerShell = true;
    baseHeight = 34.0;
  };

  scale = {
    min = 0.6;
    max = 1.2;
  };

  hardware = {
    battery = config.laplace.hardware.battery.name or null;
    backlight = config.laplace.hardware.backlight.device or null;
  };

  weather = {
    enable = true;
    productId = "IDN10064";
    interval = 900;
  };

  layout = {
    padding = "custom/padd";
    cap = {
      left = "custom/l_end";
      right = "custom/r_end";
    };

    left = [
      [
        "cpu"
        "memory"
        "disk"
      ]
      [
        "niri/workspaces"
        "niri/window"
      ]
    ];

    centre = [
      [
        "custom/weather"
        "custom/events"
        "clock"
      ]
    ];

    right = [
      ["tray"]
      [
        "battery"
        "backlight"
        "wireplumber"
        "network"
      ]
    ];
  };

  modules = {
    "niri/window" = {
      format = "{}";
      rewrite = {
        "(.*) - Mozilla Thunderbird" = " $1";
        "(.*) — Mozilla Firefox" = " $1";
        "(.*) — Zen Browser" = "󰖟  $1";
        "(.*) — Brave" = "󰖟 $1";
        "(.*) — Tor Browser" = " $1";
        "Tor Browser" = " Tor Browser";
        "(.*) - mpv" = "󰗃 $1";
        "(.*) – Doom Emacs" = " $1";
        "(.*) Discord \\| (.*)" = "  $2";
        "class<org.wezfurlong.wezterm>" = "";
        "class<foot>" = "";
      };
    };

    memory = {
      format = "󰍛 {}% ";
      format-alt = "󰍛 {used}/{total} GiB";
      interval = 5;
    };

    cpu = {
      format = "󰻠 {usage}% ";
      format-alt = "󰻠 {avg_frequency} GHz";
      interval = 5;
    };

    disk = {
      format = "󰋊 {}%";
      format-alt = "󰋊 {used}/{total} GiB";
      interval = 5;
      path = "/";
    };

    battery = {
      interval = 60;
      states = {
        warning = 30;
        critical = 15;
      };
      format-icons = [
        ""
        ""
        ""
        ""
        ""
      ];
      format = "{icon} {capacity}%";
      max-length = 25;
    };

    backlight = {
      format = "{icon} {percent}%";
      format-icons = [
        ""
        ""
      ];
    };

    wireplumber = {
      format = "{icon} {volume}%";
      format-muted = "";
      on-click = lib.getExe pkgs.pwvucontrol;
      format-icons = [
        ""
        ""
        ""
      ];
    };

    clock = {
      rotate = 0;
      format = " {:%H:%M}";
      tooltip-format = "<tt><big>{calendar}</big></tt>";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        on-scroll = 1;
        on-click-right = "mode";
        format = {
          months = "<span color='#ffead3'><b>{}</b></span>";
          weekdays = "<span color='#ffcc66'><b>{}</b></span>";
          today = "<span color='#ff6699'><b>{}</b></span>";
        };
      };
    };

    tray = {
      icon-size = 18;
      spacing = 5;
    };

    network = {
      format-wifi = " {bandwidthUpBytes}  {bandwidthDownBytes} ";
      format-ethernet = "󱘖 Wired";
      tooltip-format = "󱘖 {ipaddr} ({signalStrength}%)";
      format-linked = "󱘖 {ifname} (No IP)";
      format-disconnected = " Disconnected";
      format-alt = "󰤨 {signalStrength}%";
      interval = 5;
    };

    bluetooth = {
      format = "";
      format-disabled = "";
      format-connected = " {num_connections}";
      tooltip-format = " {device_alias}";
      tooltip-format-connected = "{device_enumerate}";
      tooltip-format-enumerate-connected = " {device_alias}";
    };

    "custom/events" = {
      format = "";
      interval = "once";
      tooltip = false;
    };
  };

  theme = {
    font = let
      hostName = config.networking.hostName or "";
      baseSize =
        if hostName == "phobos"
        then 12
        else 10;
    in {
      family = "IosevkaCadmus Nerd Font";
      weight = "bold";
      inherit baseSize;
    };

    metrics = {
      size = {
        base = 10.0;
        min = 0;
      };
      margin = {
        base = 3.0;
        min = 1;
      };
      padS = {
        base = 3.0;
        min = 1;
      };
      padM = {
        base = 4.0;
        min = 1;
      };
      padActive = {
        base = 12.0;
        min = 6;
      };
      modVMargin = {
        base = 4.0;
        min = 2;
      };
      rLarge = {
        base = 21.0;
        min = 8;
      };
      rMed = {
        base = 16.0;
        min = 6;
      };
      rSmall = {
        base = 9.0;
        min = 5;
      };
      rTiny = {
        base = 7.0;
        min = 4;
      };
    };

    colours = {
      "bar-bg" = "rgba(0, 0, 0, 0.1)";
      "main-color" = "#ffffff";
      "main-bg" = "#000000";
      "tool-bg" = "#1e1e2e";
      "tool-color" = "#7788AA";
      "tool-border" = "#000000";
      "wb-color" = "#7788AA";
      "wb-act-bg" = "#a6adc8";
      "wb-act-color" = "#313244";
      "wb-hvr-bg" = "#f5c2e7";
      "wb-hvr-color" = "#313244";
    };

    selectors.modules = [
      "cpu"
      "memory"
      "battery"
      "wireplumber"
      "disk"
      "clock"
      "workspaces"
      "window"
      "taskbar"
      "network"
      "bluetooth"
      "pulseaudio"
      "mpris"
      "backlight"
      "custom-updates"
      "custom-wallchange"
      "custom-mode"
      "custom-cliphist"
      "custom-power"
      "custom-wbar"
      "custom-l_end"
      "custom-r_end"
      "custom-sl_end"
      "custom-sr_end"
      "custom-rl_end"
      "custom-rr_end"
      "custom-weather"
      "custom-events"
      "tray"
    ];
  };
}
