{config, ...}: let
  size =
    if config.networking.hostName == "phobos"
    then 5
    else 8;
in {
  global = {
    monitor = 1;
    frame_color = "#ffffff";
    separator_color = "#ffffff";
    width = 300;
    height = 228;
    offset = "0x15";
    font = "JBMono Nerd Font ${toString size}";
    corner_radius = size;
    origin = "top-center";
    notification_limit = 3;
    idle_threshold = 120;
    ignore_newline = "no";
    mouse_left_click = "close_current";
    mouse_right_click = "close_all";
    sticky_history = "yes";
    history_length = 20;
    show_age_threshold = 50;
    ellipsize = "middle";
    padding = 10;
    always_run_script = true;
    frame_width = 2;
    transparency = 60;
    progress_bar = true;
    progress_bar_frame_width = 0;
    highlight = "#b4befe";
    icon_position = "right";
  };
  fullscreen_delay_everything.fullscreen = "delay";
  urgency_low = {
    background = "#000000";
    foreground = "#ffffff";
    timeout = 5;
  };
  urgency_normal = {
    background = "#000000";
    foreground = "#ffffff";
    timeout = 6;
  };
  urgency_critical = {
    background = "#000000";
    foreground = "#f38ba8";
    frame_color = "#f38ba8";
    timeout = 0;
  };
}
