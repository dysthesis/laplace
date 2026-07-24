{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    escapeShellArg
    getExe
    getExe'
    mkIf
    optionalAttrs
    ;
  inherit (builtins) elem;
  cfg = config.laplace.display;

  enabled = elem "wayland" cfg.servers && cfg.wayland.compositor == "niri";
  wallpaper = "${../../../../../../user/assets/wallpaper.png}";
  defaultLocation = {
    latitude = 0;
    longitude = 0;
  };
  location = defaultLocation // (config.location or {});
  hasLocation = (location.latitude != 0) || (location.longitude != 0);

  lockCommand = "${getExe pkgs.configured.swaylock} -f";
  powerOffCommand = "${getExe pkgs.configured.niri} msg action power-off-monitors";
  idleCommand = pkgs.writeShellScript "niri-idle" ''
    exec ${getExe pkgs.swayidle} -w \
      timeout 300 ${escapeShellArg lockCommand} \
      timeout 600 ${escapeShellArg powerOffCommand} \
      before-sleep ${escapeShellArg lockCommand} \
      lock ${escapeShellArg lockCommand}
  '';

  sessionService = description: execStart: {
    inherit description;
    partOf = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      ExecStart = execStart;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
in {
  config = mkIf enabled {
    laplace.display.wayland.sessionCommand = getExe' pkgs.configured.niri "niri-session";

    laplace.display.checkCommands = [
      ''
        ${config.programs.niri.package}/bin/niri validate
        test -x ${pkgs.configured.waybar}/bin/waybar
        test -x ${pkgs.configured.fuzzel}/bin/fuzzel
        test -x ${pkgs.configured.dunst}/bin/dunst
        test -x ${pkgs.configured.foot}/bin/foot
      ''
    ];

    programs.niri = {
      enable = true;
      package = pkgs.configured.niri;
      useNautilus = false;
    };

    # Gate Niri's user services to avoid duplicates after compositor changes.
    systemd.user.services =
      {
        waybar = sessionService "Waybar status bar" (getExe pkgs.configured.waybar);
        dunst = sessionService "Dunst notification daemon" (getExe pkgs.configured.dunst);
        swaybg = sessionService "Wayland wallpaper" "${getExe pkgs.swaybg} -i ${wallpaper} -m fill";
        swayidle = sessionService "Wayland idle lock manager" "${idleCommand}";
      }
      // optionalAttrs hasLocation {
        wlsunset = sessionService "Wayland colour temperature" "${getExe pkgs.wlsunset} -t 3700 -T 6200 -g 1.0 -l ${toString location.latitude} -L ${toString location.longitude}";
      };
  };
}
