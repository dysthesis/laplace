{
  config,
  pkgs,
  ...
}:
let
  weather = pkgs.stdenv.mkDerivation {
    name = "weather";
    buildInputs = [
      (pkgs.python311.withPackages (pythonPackages: with pythonPackages; [ ftputil ]))
    ];
    unpackPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cp ${./weather.py} $out/bin/weather
      chmod +x $out/bin/weather
    '';
  };
  waybarConf = {
    layer = "top";
    position = "bottom";
    mod = "dock";
    height = if config.networking.hostName == "yaldabaoth" then 28 else 34;
    exclusive = true;
    passthrough = false;
    gtk-layer-shell = true;
    modules-left = [
      "custom/padd"
      "custom/l_end"
      "cpu"
      "memory"
      "disk"
      "custom/r_end"
      "custom/l_end"
      "hyprland/workspaces"
      "hyprland/window"
      "custom/r_end"
      ""
      "custom/padd"
    ];
    modules-center = [
      "custom/padd"
      "custom/l_end"
      "custom/weather"
      "custom/events"
      "clock"
      "custom/r_end"
      "custom/padd"
    ];
    modules-right = [
      "custom/padd"
      "custom/l_end"
      "tray"
      "custom/r_end"
      "custom/l_end"
      "battery"
      "backlight"
      "wireplumber"
      "network"
      "custom/r_end"
      "custom/padd"
    ];
    "hyprland/window" = {
      format = "{}";
      rewrite = {
        "(.*) - Mozilla Thunderbird" = " $1";
        "(.*) — Mozilla Firefox" = " $1";
        "(.*) — Brave" = "󰖟 $1";
        "(.*) — Tor Browser" = " $1";
        "Tor Browser" = " Tor Browser";
        "(.*) - mpv" = "󰗃 $1";
        "(.*) – Doom Emacs" = " $1";
        "(.*) Discord \\| (.*)" = "  $2";
        "class<org.wezfurlong.wezterm>" = "";
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
      bat = "BAT1";
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
      device = "amdgpu_bl0";
      format = "{icon} {percent}%";
      format-icons = [
        ""
        ""
      ];
    };

    wireplumber = {
      format = "{icon} {volume}%";
      format-muted = "";
      on-click = "helvum";
      format-icons = [
        ""
        ""
        ""
      ];
    };

    clock = {
      rotate = 0;
      format = " {:%H:%M}";
      # format-alt = "{:%R 󰃭 %d·%m·%y}";
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

    "custom/weather" = {
      tooltip = true;
      format = "{} ";
      interval = 30;
      exec = "${weather}/bin/weather waybar IDN10064";
      return-type = "json";
    };
    "custom/l_end" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };
    "custom/r_end" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };
    "custom/sl_end" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };
    "custom/sr_end" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };
    "custom/rl_end" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };
    "custom/rr_end" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };
    "custom/padd" = {
      format = "  ";
      interval = "once";
      tooltip = false;
    };
  };
in
pkgs.writeText "waybar-config.json" (builtins.toJSON waybarConf)
