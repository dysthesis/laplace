{
  sway,
  swayidle,
  swaylock,
  pkgs,
  lib,
  writeTextFile,
  writeShellScriptBin,
  jq,
  config,
  ...
}: let
  inherit (lib) getExe;
  cfg = config.networking.hostName == "phobos";
  fontSize =
    if cfg
    then 5
    else 8;
  # Generate configurations for a signle monitor
  monitorToSwayConfig = monitor: let
    fragments = [
      "output ${monitor.name}"
      "mode ${toString monitor.width}x${toString monitor.height}"
      (lib.optionalString (monitor.pos.x != null && monitor.pos.y != null) "pos ${toString monitor.pos.x} ${toString monitor.pos.y}")
      "bg ${../hyprland/wallpaper.png} fill"
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

  mkScratchpad = scratchpad: ''
    for_window [app_id="${scratchpad.name}"] move scratchpad
    for_window [app_id="${scratchpad.name}"] scratchpad show
    for_window [app_id="${scratchpad.name}"] position center
    for_window [app_id="${scratchpad.name}"] resize set 75ppt 75ppt
    bindsym $mod+${scratchpad.prefix} exec sh -c '${sway}/bin/swaymsg [app_id="${scratchpad.name}"] scratchpad show || exec ${scratchpad.cmd}'
  '';
  scratchpads = [
    {
      name = "signal";
      prefix = "s";
      cmd = "${getExe pkgs.signal-desktop} --enable-features=UseOzonePlatform --ozone-platform=wayland";
    }
    rec {
      name = "ghostty.term";
      prefix = "t";
      cmd = "${pkgs.configured.ghostty}/bin/ghostty --class=${name}";
    }
    rec {
      name = "ghostty.notes";
      prefix = "n";
      cmd = let
        notes-launcher = writeShellScriptBin "notes-launcher" ''
          exec ${pkgs.configured.ghostty}/bin/ghostty --class=${name} -e ${pkgs.tmux}/bin/tmux new-session -As Notes -c "$HOME/Documents/Notes/Contents" 'direnv exec . nvim'
        '';
      in "${getExe notes-launcher}";
    }
    rec {
      name = "ghostty.music";
      prefix = "m";
      cmd = "${pkgs.configured.ghostty}/bin/ghostty --class=${name} -e spotify_player";
    }
  ];

  scratchpadCfg =
    scratchpads
    |> lib.map mkScratchpad
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

  focusWs =
    writeShellScriptBin "focus_ws"
    /*
    bash
    */
    ''
      target="$1"
      focused="$(${sway}/bin/swaymsg -t get_outputs | ${lib.getExe jq} -r '.[] | select(.focused == true) | .name')"
      echo "Currently focused: $focused" >> $HOME/.cache/focus_ws_log
      echo "Currently focused: $focused" >> $HOME/.cache/focus_ws_log
      ${sway}/bin/swaymsg workspace "$target"
      ${sway}/bin/swaymsg move workspace to "$focused"
    ''
    |> lib.getExe;
in
  writeTextFile {
    name = "sway-config";
    text = ''
      ${monitorConfig}

      smart_borders on
      default_border pixel
      titlebar_border_thickness 0
      titlebar_padding 1

      font JBMono Nerd Font ${toString fontSize}

      set $mod Mod4
      # Home row direction keys, like vim
      set $left h
      set $down j
      set $up k
      set $right l
      set $term ${lib.getExe pkgs.configured.ghostty}
      set $menu ${pkgs.configured.bemenu}/bin/bemenu-run

      ${scratchpadCfg}

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
      bindsym $mod+1 exec ${focusWs} 1
      bindsym $mod+2 exec ${focusWs} 2
      bindsym $mod+3 exec ${focusWs} 3
      bindsym $mod+4 exec ${focusWs} 4
      bindsym $mod+5 exec ${focusWs} 5
      bindsym $mod+6 exec ${focusWs} 6
      bindsym $mod+7 exec ${focusWs} 7
      bindsym $mod+8 exec ${focusWs} 8
      bindsym $mod+9 exec ${focusWs} 9

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
      bindsym $mod+Shift+s layout stacking
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
          swaybar_command ${sway}/bin/swaybar
          position bottom
          height 18

          # When the status_command prints a new line to stdout, swaybar updates.
          # The default just shows the current date and time.
          status_command ${lib.getExe pkgs.i3status}
          colors {
              statusline #ffffff
              background #000000
              inactive_workspace #00000000 #00000000 #5c5c5c
          }
      }

      input * {
        natural_scroll enabled
      }
    '';
  }
