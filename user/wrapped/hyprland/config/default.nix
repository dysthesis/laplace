{
  hypridle ? pkgs.hypridle,
  hyprlock ? pkgs.hyprlock,
  hyprland ? pkgs.hyprland,
  pkgs,
  inputs,
  lib,
  config,
  ...
}: let
  startup = let
    inherit (lib) foldr;

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
        foldr (
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
      # Syncthing tray needs the Qt theme.
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
    };

    group = {
      "col.border_active" = "rgba(89b4faff)";
      "col.border_inactive" = "rgba(6c7086ff)";
      groupbar = {
        font_family = "IosevkaCadmus Nerd Font";
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
    };

    misc = {
      disable_splash_rendering = true;
      force_default_wallpaper = 0;
      disable_hyprland_logo = true;
      font_family = "IosevkaCadmus Nerd Font";

      vfr = true;
      vrr = true;

      enable_swallow = true; # hide windows that spawn other windows
      swallow_regex = "foot";

      mouse_move_enables_dpms = true;
      key_press_enables_dpms = true;
      disable_autoreload = true; # config is store-path readonly on nixos anyway
    };

    input = {
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
  // (import ./keybinds.nix {
    inherit
      pkgs
      lib
      hyprland
      hyprlock
      inputs
      ;
  })
  // (import ./input.nix)
  // (import ./rules.nix)
