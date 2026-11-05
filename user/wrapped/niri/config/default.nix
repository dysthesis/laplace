{
  pkgs,
  lib,
  config,
  terminal,
  launcher,
  integrated,
  shellCommand,
  ...
}: let
  model = import ./model.nix {inherit lib;};
  renderer = import ./render.nix {inherit lib;};

  context = {
    monitors = lib.attrByPath ["laplace" "hardware" "monitors"] [] config;
    inherit integrated;
    palette = import ../../../../system/display/servers/wayland/desktop/palette.nix;
    terminalAppId = terminal.appId;
    deps =
      {
        terminal = terminal.launch;
        launcher = launcher.open;
        brightnessctl = [(lib.getExe pkgs.brightnessctl)];
        wpctl = [(lib.getExe' pkgs.wireplumber "wpctl")];
        xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
      }
      // lib.optionalAttrs integrated {
        noctalia = shellCommand;
        clipboard = launcher.clipboard or null;
      };
  };

  serialised = renderer.render (model.mkModel context);
in
  pkgs.writeText "niri-config.kdl" serialised
