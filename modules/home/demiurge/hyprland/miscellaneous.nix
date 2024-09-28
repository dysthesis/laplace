{
  wayland.windowManager.hyprland.settings = {
    gestures.workspace_swipe = true;
    xwayland.force_zero_scaling = true;

    general = {
      gaps_in = 4;
      gaps_out = 8;

      border_size = 1;

      layout = "master";
      "col.active_border" = "rgb(ffffff)";

      apply_sens_to_raw = 0;
    };

    misc = {
      # disable redundant renders
      disable_splash_rendering = true;
      force_default_wallpaper = 0;
      disable_hyprland_logo = true;
      font_family = "JetBrainsMono Nerd Font";

      vfr = true;

      # window swallowing
      enable_swallow = true; # hide windows that spawn other windows
      swallow_regex = "^(org.wezfurlong.wezterm)$";

      # dpms
      mouse_move_enables_dpms = true; # enable dpms on mouse/touchpad action
      key_press_enables_dpms = true; # enable dpms on keyboard action
      disable_autoreload = true; # autoreload is unnecessary on nixos, because the config is readonly anyway
    };

    input = {
      # keyboard layout
      kb_layout = "us";
      kb_options = "caps:escape";
      follow_mouse = 1;
      sensitivity = 0.0;
      touchpad = {
        clickfinger_behavior = true;
        tap-to-click = false;
        scroll_factor = 0.5;
        natural_scroll = true;
      };
    };
  };
}
