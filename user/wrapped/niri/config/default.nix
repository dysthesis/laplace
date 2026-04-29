{
  pkgs,
  lib,
  config,
  ...
}: let
  model = import ./model.nix {inherit lib;};
  renderer = import ./render.nix {inherit lib;};

  context = {
    monitors = lib.attrByPath ["laplace" "hardware" "monitors"] [] config;
    deps = {
      terminal = lib.getExe pkgs.configured.foot;
      launcher = lib.getExe pkgs.configured.fuzzel;
      brightnessctl = lib.getExe pkgs.brightnessctl;
      locker = lib.getExe pkgs.configured.swaylock;
      wpctl = lib.getExe' pkgs.wireplumber "wpctl";
      xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
    };
  };

  serialised = renderer.render (model.mkModel context);
in
  pkgs.writeText "niri-config.kdl" serialised
