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
    mkIf
    optionalAttrs
    ;
  inherit (builtins) elem;
  cfg = config.laplace.display.servers;

  isWayland = elem "wayland" cfg;
  wallpaper = "${../../../../user/assets/wallpaper.png}";
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
  config = mkIf isWayland {
    programs.niri = {
      enable = true;
      package = pkgs.configured.niri;
      useNautilus = false;
    };

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

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
