{
  pkgs,
  lib,
  config,
  ...
}: let
  model = import ./model.nix {inherit lib;};
  renderer = import ./render.nix {inherit lib;};
  desktopEnabled = config.laplace.display.wayland.desktop.enable;

  context = {
    monitors = lib.attrByPath ["laplace" "hardware" "monitors"] [] config;
    desktop = {
      enable = desktopEnabled;
      palette = import ../../../../system/display/servers/wayland/desktop/palette.nix;
    };
    deps =
      {
        terminal = lib.getExe pkgs.configured.foot;
        launcher = lib.getExe (
          if desktopEnabled
          then pkgs.configured.vicinae
          else pkgs.configured.fuzzel
        );
        brightnessctl = lib.getExe pkgs.brightnessctl;
        locker = lib.getExe pkgs.configured.swaylock;
        wpctl = lib.getExe' pkgs.wireplumber "wpctl";
        xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
      }
      // lib.optionalAttrs desktopEnabled {
        noctalia = lib.getExe pkgs.configured.noctalia;
      };
  };

  serialised = renderer.render (model.mkModel context);
in
  pkgs.writeText "niri-config.kdl" serialised
