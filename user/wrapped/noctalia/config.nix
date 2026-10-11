{
  vicinaeExe,
  swaylockExe,
  niriExe,
}: let
  wallpaper = "${../../assets/wallpaper.png}";
in {
  shell = {
    telemetry_enabled = false;
    setup_wizard_enabled = false;
    clipboard_enabled = false;
    polkit_agent = false;
    screen_time_enabled = false;
    font_family = "Atkinson Hyperlegible Next";
    corner_radius_scale = 0.9;
    button_borders = true;
    input_borders = true;
    popup_borders = true;
    card_borders = false;
    popup_shadows = false;
    settings_window_translucent = false;
    settings_show_advanced = false;
    show_location = false;

    animation = {
      enabled = true;
      speed = 1.4; # Short transitions; set enabled = false to eliminate shell motion.
    };
    shadow = {
      direction = "down";
      alpha = 0.18;
    };
    panel = {
      transparency_mode = "solid";
      borders = true;
      shadow = true;
      list_item_background = false;
      control_center_placement = "attached";
      open_near_click_control_center = true;
      open_near_click_session = true;
    };
    session.actions = [
      {
        action = "command";
        label = "Lock";
        glyph = "lock";
        shortcut = "1";
        command = "${swaylockExe} -f";
      }
      {
        action = "logout";
        shortcut = "2";
        command = "${niriExe} msg action quit";
      }
      {
        action = "suspend";
        shortcut = "3";
      }
      {
        action = "reboot";
        shortcut = "4";
        countdown_seconds = 5;
        variant = "destructive";
      }
      {
        action = "shutdown";
        shortcut = "5";
        countdown_seconds = 5;
        variant = "destructive";
      }
    ];
  };

  wallpaper = {
    enabled = true;
    default.path = wallpaper;
    fill_mode = "crop";
    transition = ["fade"];
    transition_duration = 220;
    transition_on_startup = false;
  };

  theme = {
    mode = "dark";
    source = "custom";
    custom_palette = "Minimal";
  };

  lockscreen.enabled = false;
  idle.behavior = {
    lock.enabled = false;
    screen-off.enabled = false;
  };
  system.monitor.enabled = false;
  weather.enabled = false;
  audio.enable_overdrive = false;

  brightness = {
    enable_ddcutil = true;
    sync_all_monitors = true;
    minimum_brightness = 0.05;
    monitor = {
      "DP-2".backend = "ddcutil";
      "HDMI-A-1".backend = "ddcutil";
    };
  };

  desktop_widgets.enabled = false;

  bar.main = {
    enabled = true;
    position = "top";
    auto_hide = false;
    reserve_space = true;
    layer = "top";

    margin_ends = 0;
    margin_edge = 0;
    thickness = 36;
    padding = 8;
    widget_spacing = 8;
    radius = 0;
    background_opacity = 1.0;
    compositor_blur = false;
    border = "outline";
    border_width = 1;
    shadow = false;

    font_weight = 500;
    font_scale = 1.0;
    hover_highlight = true;
    capsule = false;

    start = ["apps" "workspaces"];
    center = ["clock"];
    end = [
      "tray"
      "network"
      "volume"
      "notifications"
      "control-center"
    ];
  };

  widget = {
    apps = {
      type = "custom_button";
      glyph = "search";
      label = "Apps";
      tooltip = "Applications and commands · Super+Space";
      actions.left = "exec ${vicinaeExe} toggle";
    };
    workspaces = {
      style = "regular";
      show_labels = true;
      show_all_outputs = false;
      label_source = "id";
      max_label_chars = 2;
      focused_color = "primary";
      occupied_color = "on_surface_variant";
      empty_color = "outline";
      urgent_color = "error";
      change_color_on_hover = false;
    };
    clock = {
      format = "{:%a %d %b  %H:%M}";
      tooltip_format = "{:%A, %d %B %Y}";
      color = "on_surface";
      font_weight = 600;
      anchor = true;
    };
    tray = {
      drawer = true;
      drawer_columns = 3;
      drawer_item_size = 22;
      hide_passive = true;
    };
    notifications = {
      hide_when_no_unread = false; # Keeps the notification/DND affordance available.
      color = "on_surface_variant";
    };
    network = {
      show_label = false;
      vpn_status = "both";
      color = "on_surface_variant";
    };
    volume = {
      show_label = false;
      color = "on_surface_variant";
    };
    control-center = {
      color = "on_surface";
    };
  };

  control_center.shortcuts = [
    {type = "wifi";}
    {type = "bluetooth";}
    {type = "caffeine";}
    {type = "notification";}
  ];

  notification = {
    enable_daemon = true;
    show_actions = true;
    show_app_name = true;
    position = "top_right";
    layer = "top";
    width = 350;
    scale = 1.0;
    background_opacity = 1.0;
    border = true;
    border_color = "outline";
    border_width = 1;
    offset_x = 12;
    offset_y = 44; # Clear the 36 px edge bar.
    follow_focused_output = true;
    max_visible = 2;
    keep_dismissed_in_history = true;
    history_retention_hours = 168;
  };

  osd = {
    position = "bottom_center";
    hide_delay_ms = 1300;
    background_opacity = 1.0;
    border = true;
    border_color = "outline";
    border_width = 1;
    offset_y = 24;
    follow_focused_output = true;
    kinds.media = false; # Suppress repeated music-track popups.
  };

  dock.enabled = false;
}
