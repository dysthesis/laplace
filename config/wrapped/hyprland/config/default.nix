{
  hypridle ? pkgs.hypridle,
  hyprlock ? pkgs.hyprlock,
  hyprland ? pkgs.hyprland,
  pkgs,
  lib,
  config,
  ...
}: let
  startup = let
    inherit (lib) fold;

    inherit (lib.cli) toGNUCommandLineShell;
    wlsunset = let
      args = toGNUCommandLineShell {} {
        t = "3700";
        T = "6200";
        g = "1.0";
        l = config.location.latitude;
        L = config.location.longitude;
      };
    in "${pkgs.wlsunset}/bin/wlsunset ${args} &";
    swaybg = ''
      ${lib.getExe pkgs.swaybg} -i ${./wallpaper.png} &
    '';
    dunst = "${pkgs.configured.dunst}/bin/dunst &";
    wlr-randr = let
      wlr-randr = lib.getExe pkgs.wlr-randr;
      wlr-randr-args =
        fold (
          curr: acc: "${acc} --output ${curr.name} --mode ${toString curr.width}x${toString curr.height}@${toString curr.refreshRate}Hz"
        ) ""
        config.laplace.hardware.monitors;
    in ''
      ${wlr-randr} ${wlr-randr-args}
    '';
  in
    pkgs.writeShellScriptBin "startup" ''
      if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        eval $(dbus-launch --exit-with-session --sh-syntax)
      fi
      ## https://bbs.archlinux.org/viewtopic.php?id=224652
      # Need QT theme for syncthing tray
      systemctl import-environment --user DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS \
        QT_QPA_PLATFORMTHEME PATH XCURSOR_SIZE XCURSOR_THEME

      ${wlsunset}
      ${swaybg}
      ${dunst}
      ${wlr-randr}
      ${lib.getExe pkgs.configured.waybar}
      ${lib.getExe hypridle}
    '';
in
  {
    env = [
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
      "HYPRCURSOR_THEME,Bibata-Modern-Classic-Hyprcursor"
      "HYPRCURSOR_SIZE,${toString 16}"
    ];
    exec-once = [
      "${lib.getExe startup}"
    ];

    master = {
      new_status = "slave";
      special_scale_factor = 0.8;
      mfact = 0.5;
    };

    dwindle = {
      pseudotile = false;
      preserve_split = "yes";
      # no_gaps_when_only = false;
    };

    group = {
      "col.border_active" = "rgba(89b4faff)";
      "col.border_inactive" = "rgba(6c7086ff)";
      groupbar = {
        font_family = "JBMono Nerd Font";
        font_size = 8;
        "col.active" = "rgba(89b4faff)";
        "col.inactive" = "rgba(6c7086ff)";
      };
    };

    general = {
      gaps_in = 4;
      gaps_out = 8;

      border_size = 1;

      layout = "master";
      "col.active_border" = "rgb(ffffff)";

      # apply_sens_to_raw = 0;
    };

    misc = {
      # disable redundant renders
      disable_splash_rendering = true;
      force_default_wallpaper = 0;
      disable_hyprland_logo = true;
      font_family = "JBMono Nerd Font";

      vfr = true;
      vrr = true;

      # window swallowing
      enable_swallow = true; # hide windows that spawn other windows
      swallow_regex = "com.mitchellh.ghostty";

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
    xwayland.force_zero_scaling = true;

    debug.disable_logs = false;
  }
  // (import ./animations.nix)
  // (import ./decoration.nix)
  // (import ./keybinds.nix {inherit pkgs lib hyprland hyprlock;})
  // (import ./input.nix)
  // (import ./rules.nix)
