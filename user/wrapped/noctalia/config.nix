let
  wallpaper = "${../../assets/wallpaper.png}";
in {
  shell = {
    telemetry_enabled = false;
    setup_wizard_enabled = false;
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
      border_color = "outline";
      border_width = 1.0;
      shadow = true;
      list_item_background = false;
      launcher_placement = "floating";
      launcher_position = "center";
      clipboard_placement = "floating";
      clipboard_position = "center";
      control_center_placement = "attached";
    };
    launcher = {
      show_icons = true;
      show_app_origin_indicator = false;
      compact = false;
      app_grid = false;
      sort_by_usage = true;
    };
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
  location = {
    latitude = 33.9;
    longitude = 151.2;
  };

  brightness = {
    enable_ddcutil = true;
    sync_all_monitors = true;
    monitor = {
      "DP-2".backend = "ddcutil";
      "HDMI-A-1".backend = "ddcutil";
    };
  };

  desktop_widgets = {
    enable = true;
    widget.weather = {
      type = "weather";
      output = "DP-2";
      cx = "960.0";
      cy = "540.0";
      box_width = "0.0";
      box_height = "0.0";
      rotation = "0.0";
      flip_x = "false";
      flip_y = "false";
    };
  };

  bar.main = {
    enabled = true;
    position = "top";
    auto_hide = false;
    reserve_space = true;
    layer = "top";

    margin_ends = 570;
    margin_edge = 10;
    thickness = 42;
    padding = 12;
    widget_spacing = 10;
    radius = 12;
    background_opacity = 0.75;
    compositor_blur = true;
    border = "outline";
    border_width = 1;
    shadow = false;

    font_weight = 500;
    font_scale = 1.0;
    hover_highlight = true;
    show_tooltip = true;
    capsule = false;

    start = ["workspaces"];
    center = ["clock"];
    end = [
      "tray"
      "notifications"
      "network"
      "volume"
      "battery"
      "control-center"
    ];
  };

  widget = {
    workspaces = {
      style = "regular";
      show_labels = true;
      label_source = "id";
      max_label_chars = 2;
      focused_color = "primary";
      occupied_color = "on_surface_variant";
      empty_color = "outline";
      urgent_color = "error";
      change_color_on_hover = false;
    };
    clock = {
      format = "{:%H:%M}";
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
    battery = {
      display_mode = "glyph";
      show_label = true;
      label_content = "percent";
      hide_when_full = false;
      color = "on_surface_variant";
    };
    control-center = {
      capsule = true;
      capsule_fill = "surface_variant";
      capsule_opacity = 1.0;
      capsule_padding = 8;
      color = "on_surface";
    };
  };

  notification = {
    enable_daemon = true;
    show_actions = true;
    show_app_name = true;
    position = "top_right";
    layer = "top";
    width = 350;
    scale = 1.0;
    background_opacity = 0.99;
    border = true;
    border_color = "outline";
    border_width = 1;
    offset_x = 16;
    offset_y = 64; # Avoid overlap with 10 px inset + 42 px bar.
    follow_focused_output = true;
    max_visible = 3;
    keep_dismissed_in_history = true;
  };

  osd = {
    position = "bottom_center";
    hide_delay_ms = 1300;
    background_opacity = 0.99;
    border = true;
    border_color = "outline";
    border_width = 1;
    offset_y = 24;
    follow_focused_output = true;
    kinds.media = false; # Suppress repeated music-track popups.
  };

  dock.enabled = false;
}
