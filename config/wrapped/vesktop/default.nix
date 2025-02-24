{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit lib;
    inherit pkgs;
  };
in
mkNixPak {
  config =
    { sloth, ... }:
    let
      envSuffix = envKey: suffix: sloth.concat' (sloth.env envKey) suffix;
    in
    rec {
      app.package = pkgs.vesktop;
      flatpak.appId = "dev.vencord.Vesktop";

      # Enable D-Bus and set policies
      dbus.enable = true;
      gpu = {
        enable = true;
        provider = "bundle";
      };

      dbus.policies = {
        "org.kde.StatusNotifierWatcher" = "talk"; # Tray functionalities on KDE
        "${flatpak.appId}" = "own";
        "org.freedesktop.DBus" = "talk";
        "org.gtk.vfs.*" = "talk";
        "org.gtk.vfs" = "talk";
        "ca.desrt.dconf" = "talk";
        "org.freedesktop.portal.*" = "talk";
        "org.a11y.Bus" = "talk";
      };
      fonts = {
        enable = true;
        fonts = config.fonts.packages;
      };
      locale.enable = true;
      bubblewrap = {
        network = true;
        shareIpc = true;
        sockets = {
          x11 = lib.mkDefault true; # Enable X11 socket
          pulse = lib.mkDefault true; # Enable Pulseaudio socket
        };
        bind.ro = [
          sloth.xdgVideosDir # Read-only access to Videos
          sloth.xdgPicturesDir # Read-only access to Pictures
          "/run/dbus/system_bus_socket" # Not entirely sure why if needed but it was warning in terminal that it couldn't be found
          "/etc/resolv.conf"
          (envSuffix "XDG_RUNTIME_DIR" "/doc")
          (sloth.concat' sloth.xdgConfigHome "/gtk-2.0")
          (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
          (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
          (sloth.concat' sloth.xdgConfigHome "/fontconfig")
        ];
        bind.rw = [
          (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/pipewire-0") # Pipewire interfacing
          (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/speech-dispatcher") # For TTS and VcNarrator
          (sloth.concat' sloth.homeDir "/.steam") # Needed for SteamOS integration
          sloth.xdgDownloadDir # For drag-and-drop and download management
          (sloth.concat' sloth.xdgConfigHome "/vesktop") # Vesktop configuration/data directory
          [
            (envSuffix "HOME" "/.var/app/${flatpak.appId}/cache")
            sloth.xdgCacheHome
          ]
          (sloth.concat' sloth.xdgCacheHome "/fontconfig")
          (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")

          (sloth.concat [
            (sloth.env "XDG_RUNTIME_DIR")
            "/"
            (sloth.envOr "WAYLAND_DISPLAY" "no")
          ])

          (envSuffix "XDG_RUNTIME_DIR" "/at-spi/bus")
          (envSuffix "XDG_RUNTIME_DIR" "/gvfsd")
          (envSuffix "XDG_RUNTIME_DIR" "/pulse")
        ];
        bind.dev = [
          "/dev/dri" # Device access for GPU
          "/dev/video0" # Webcam access | TODO: Find a way to get all video devices
        ];
        env = {
          XDG_DATA_DIRS = lib.makeSearchPath "share" [
            pkgs.adwaita-icon-theme
            pkgs.shared-mime-info
          ];
          XCURSOR_PATH = lib.concatStringsSep ":" [
            "${pkgs.adwaita-icon-theme}/share/icons"
            "${pkgs.adwaita-icon-theme}/share/pixmaps"
          ];
        };
      };
    };
}
