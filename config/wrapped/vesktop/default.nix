{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit lib;
    inherit pkgs;
  };
in
  mkNixPak {
    config = {sloth, ...}: let
      envSuffix = envKey: suffix: sloth.concat' (sloth.env envKey) suffix;
    in rec {
      app.package = pkgs.vesktop;
      flatpak.appId = "dev.vencord.Vesktop";

      dbus.enable = true;

      gpu = {
        enable = true;
        provider = "bundle";
      };

      dbus.policies = {
        "org.kde.StatusNotifierWatcher" = "talk"; # For system tray icon
        "${flatpak.appId}" = "own";
        "org.freedesktop.DBus" = "talk";
        "org.gtk.vfs.*" = "talk";
        "ca.desrt.dconf" = "talk";
        "org.freedesktop.portal.Desktop" = "talk"; # Main portal interface
        "org.freedesktop.portal.FildesChooser" = "talk"; # File picker
        "org.a11y.Bus" = "talk"; # Accessibility
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
          wayland = lib.mkDefault true;
          pulse = lib.mkDefault true;
        };
        bind = {
          ro = [
            sloth.xdgVideosDir
            sloth.xdgPicturesDir
            "/run/dbus/system_bus_socket"
            "/etc/resolv.conf"
            # Portal helper for file access
            (envSuffix "XDG_RUNTIME_DIR" "/doc")
            # GTK/Font configuration
            (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
            (sloth.concat' sloth.xdgConfigHome "/fontconfig")
          ];
          rw = [
            # Runtime paths for various services
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/pipewire-0")
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/speech-dispatcher")
            (envSuffix "XDG_RUNTIME_DIR" "/at-spi/bus")
            (envSuffix "XDG_RUNTIME_DIR" "/gvfsd")

            # User directories
            sloth.xdgDownloadDir

            # Application-specific config and cache
            (sloth.concat' sloth.xdgConfigHome "/vesktop")
            (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")
            [
              (envSuffix "HOME" "/.var/app/${flatpak.appId}/cache")
              sloth.xdgCacheHome
            ]

            # Bind Wayland socket correctly
            (sloth.concat [
              (sloth.env "XDG_RUNTIME_DIR")
              "/"
              (sloth.envOr "WAYLAND_DISPLAY" "wayland-0")
            ])
          ];
          dev = [
            "/dev/dri" # For GPU acceleration
            "/dev/video0" # For webcam
          ];
        };

        env = {
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          # Share system mime database and icons for better integration
          XDG_DATA_DIRS = lib.makeSearchPath "share" [
            pkgs.adwaita-icon-theme
            pkgs.shared-mime-info
          ];
          # Make cursors work
          XCURSOR_PATH = lib.concatStringsSep ":" [
            "${pkgs.adwaita-icon-theme}/share/icons"
            "${pkgs.adwaita-icon-theme}/share/pixmaps"
          ];
        };
      };
    };
  }
