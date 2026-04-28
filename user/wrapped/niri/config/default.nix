{
  pkgs,
  lib,
  config,
  ...
}: let
  model = import ./model.nix {inherit lib;};
  renderer = import ./render.nix {inherit lib;};

  context = {
    location = {
      latitude = lib.attrByPath ["location" "latitude"] 0 config;
      longitude = lib.attrByPath ["location" "longitude"] 0 config;
    };
    monitors = lib.attrByPath ["laplace" "hardware" "monitors"] [] config;
    deps = {
      terminal = lib.getExe pkgs.configured.foot;
      launcher = "${pkgs.configured.bemenu}/bin/bemenu-run";
      dunst = lib.getExe pkgs.configured.dunst;
      waybar = lib.getExe pkgs.configured.waybar;
      swaybg = lib.getExe pkgs.swaybg;
      wlsunset = lib.getExe pkgs.wlsunset;
      brightnessctl = lib.getExe pkgs.brightnessctl;
      xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
      wallpaper = "${../../hyprland/config/wallpaper.png}";
    };
  };

  serialised = renderer.render (model.mkModel context);
in
  pkgs.writeText "niri-config.kdl" serialised
