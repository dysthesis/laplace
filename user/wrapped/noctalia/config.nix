{
  vicinaeExe,
  niriExe,
  config,
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
      speed = 1.4;
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

  idle.behavior = {
    lock.enabled = true;
    screen-off.enabled = false;
  };

  brightness = {
    enable_ddcutil = true;
    sync_all_monitors = true;
    minimum_brightness = 0.05;
    monitor = {
      "DP-2".backend = "ddcutil";
      "HDMI-A-1".backend = "ddcutil";
    };
  };

  desktop_widgets = {
    enabled = true;
    schema_version = 2;
    widget_order = ["calendar_main" "weather_main"];

    grid = {
      visible = true;
      cell_size = 16;
      major_interval = 4;
    };

    widget = {
      calendar_main = {
        box_height = 448.0;
        box_width = 640.0;
        cx = 1540.0;
        cy = 316.0;
        output = "DP-2";
        placement_height = 1080.0;
        placement_width = 1920.0;
        rotation = 0.0;
        type = "calendar";
      };
      weather_main = {
        box_height = 192.0;
        box_width = 352.0;
        cx = 1684.0;
        cy = 700.0;
        output = "DP-2";
        placement_height = 1080.0;
        placement_width = 1920.0;
        rotation = -0.0;
        type = "weather";
        settings = {
          background_opacity = 0.75;
          background_padding = 12;
          background_radius = 32;
          forecast_days = 3;
          show_forecast = true;
        };
      };
    };
  };

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
    center = ["clock" "weather"];
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
      tooltip = "Applications and commands";
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
    weather.color = "on_surface_variant";
    notifications = {
      hide_when_no_unread = false; # Keep notification and do-not-disturb controls available.
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
      glyph = " ";
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
    offset_y = 44; # Keep notifications below the 36 px edge bar.
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
    kinds.media = false; # Do not show a popup for each music-track change.
  };

  calendar = {
    enabled = true;
    refresh_minutes = 15;
    account.radicale = {
      type = "caldav";
      name = "Personal";
      provider = "custom";
      server_url = "https://cal.dysthesis.com";
      username = "demiurge";
      calendars = [];
      credential_source = "file";
      password_file = config.sops.secrets."caldav".path;
    };
    reminders = {
      enabled = true;
      use_event_reminders = true; # Use default_lead_minutes when use_event_reminders is false.
      default_lead_minutes = 10; # Events without reminders use this delay. Use 0 to notify at the event start.
      all_day_digest_time = "09:00"; # Show today's all-day events in one notification. Use "" to disable this notification.
    };
  };

  location = {inherit (config.location) latitude longitude;};
  nightlight = {
    enabled = true;
    force = false; # A true value applies the night temperature without the schedule.

    temperature_day = 6500; # The two temperatures are in kelvin. The minimum is temperature_night + 100.
    temperature_night = 4000;
  };

  dock.enabled = false;
}
