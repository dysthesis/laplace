{
  sway,
  swayidle,
  swaylock,
  pkgs,
  lib,
  writeTextFile,
  config,
  ...
}: let
  # Generate configurations for a signle monitor
  monitorToSwayConfig = monitor: let
    fragments = [
      "output ${monitor.name}"
      "resolution ${toString monitor.width}x${toString monitor.height}"
      "bg ${../hyprland/wallpaper.png}"
      (lib.optionalString (monitor.pos.x != null && monitor.pos.y != null) "pos ${toString monitor.pos.x} ${toString monitor.pos.y}")
    ];
  in
    # Join the fragments with spaces to form a single line.
    lib.concatStringsSep " " fragments;

  # Map all of our monitors into config text
  monitorConfig =
    config.laplace.hardware.monitors
    # For each monitor, convert them into a configuration line...
    |> lib.map monitorToSwayConfig
    # and combine them into a signle, newline-delimited string.
    |> lib.concatStringsSep "\n";

  inherit (lib.cli) toGNUCommandLineShell;
  wlsunset = let
    args = toGNUCommandLineShell {} {
      t = "3700";
      T = "6200";
      g = "1.0";
      l = config.location.latitude;
      L = config.location.longitude;
    };
  in "${pkgs.wlsunset}/bin/wlsunset ${args}";
in
  writeTextFile {
    name = "sway-config";
    text = ''
      ${monitorConfig}
      set $mod Mod4
      # Home row direction keys, like vim
      set $left h
      set $down j
      set $up k
      set $right l
      set $term ${lib.getExe pkgs.configured.ghostty}
      set $menu ${pkgs.configured.bemenu}/bin/bemenu-run

      # Set wallpaper
      output * bg ${../hyprland/wallpaper.png}

      exec ${lib.getExe swayidle} -w \
               timeout 300 '${lib.getExe swaylock} -f -c 000000' \
               timeout 600 '${sway}/bin/swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
               before-sleep '${lib.getExe swaylock} -f -c 000000'

      exec ${wlsunset}
      exec ${lib.getExe pkgs.configured.dunst}

      bindsym $mod+Return exec $term

      # Kill focused window
      bindsym $mod+q kill

      # Start your launcher
      bindsym $mod+r exec $menu

      floating_modifier $mod normal

      # Exit sway (logs you out of your Wayland session)
      bindsym $mod+Shift+q exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'

      # Move your focus around
      bindsym $mod+$left focus left
      bindsym $mod+$down focus down
      bindsym $mod+$up focus up
      bindsym $mod+$right focus right
      # Or use $mod+[up|down|left|right]
      bindsym $mod+Left focus left
      bindsym $mod+Down focus down
      bindsym $mod+Up focus up
      bindsym $mod+Right focus right

      # Move the focused window with the same, but add Shift
      bindsym $mod+Shift+$left move left
      bindsym $mod+Shift+$down move down
      bindsym $mod+Shift+$up move up
      bindsym $mod+Shift+$right move right
      # Ditto, with arrow keys
      bindsym $mod+Shift+Left move left
      bindsym $mod+Shift+Down move down
      bindsym $mod+Shift+Up move up
      bindsym $mod+Shift+Right move right

      # Switch to workspace
      bindsym $mod+1 workspace number 1
      bindsym $mod+2 workspace number 2
      bindsym $mod+3 workspace number 3
      bindsym $mod+4 workspace number 4
      bindsym $mod+5 workspace number 5
      bindsym $mod+6 workspace number 6
      bindsym $mod+7 workspace number 7
      bindsym $mod+8 workspace number 8
      bindsym $mod+9 workspace number 9
      bindsym $mod+0 workspace number 10

      # Move focused container to workspace
      bindsym $mod+Shift+1 move container to workspace number 1
      bindsym $mod+Shift+2 move container to workspace number 2
      bindsym $mod+Shift+3 move container to workspace number 3
      bindsym $mod+Shift+4 move container to workspace number 4
      bindsym $mod+Shift+5 move container to workspace number 5
      bindsym $mod+Shift+6 move container to workspace number 6
      bindsym $mod+Shift+7 move container to workspace number 7
      bindsym $mod+Shift+8 move container to workspace number 8
      bindsym $mod+Shift+9 move container to workspace number 9
      bindsym $mod+Shift+0 move container to workspace number 10

      bindsym $mod+b splith
      bindsym $mod+v splitv

      # Switch the current container between different layout styles
      bindsym $mod+s layout stacking
      bindsym $mod+w layout tabbed
      bindsym $mod+e layout toggle split

      # Make the current focus fullscreen
      bindsym $mod+f fullscreen

      # Toggle the current focus between tiling and floating mode
      bindsym $mod+Shift+space floating toggle

      # Swap focus between the tiling area and the floating area
      bindsym $mod+space focus mode_toggle

      # Move focus to the parent container
      bindsym $mod+a focus parent

      # Move the currently focused window to the scratchpad
      bindsym $mod+Shift+minus move scratchpad

      # Show the next scratchpad window or hide the focused scratchpad window.
      # If there are multiple scratchpad windows, this command cycles through them.
      bindsym $mod+minus scratchpad show
      #
      # Resizing containers:
      #
      mode "resize" {
          # left will shrink the containers width
          # right will grow the containers width
          # up will shrink the containers height
          # down will grow the containers height
          bindsym $left resize shrink width 10px
          bindsym $down resize grow height 10px
          bindsym $up resize shrink height 10px
          bindsym $right resize grow width 10px

          # Ditto, with arrow keys
          bindsym Left resize shrink width 10px
          bindsym Down resize grow height 10px
          bindsym Up resize shrink height 10px
          bindsym Right resize grow width 10px

          # Return to default mode
          bindsym Return mode "default"
          bindsym Escape mode "default"
      }
      bindsym $mod+Shift+r mode "resize"
      # Special keys to adjust volume via PulseAudio
      bindsym --locked XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindsym --locked XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+

      # Special keys to adjust brightness via brightnessctl
      bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
      bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+

      bar {
          position bottom

          # When the status_command prints a new line to stdout, swaybar updates.
          # The default just shows the current date and time.
          status_command while ${pkgs.uutils-coreutils-noprefix}/bin/date +'%Y-%m-%d %X'; do sleep 1; done

          colors {
              statusline #ffffff
              background #323232
              inactive_workspace #32323200 #32323200 #5c5c5c
          }
      }

      input * {
        natural_scroll enabled
      }
    '';
  }
