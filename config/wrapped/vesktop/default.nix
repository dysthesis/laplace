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
        "org.kde.StatusNotifierWatcher" = "talk";
        "${flatpak.appId}" = "own";
        "org.freedesktop.DBus" = "talk";
        "org.gtk.vfs.*" = "talk";
        "org.gtk.vfs" = "talk";
        "ca.desrt.dconf" = "talk";
        "org.freedesktop.portal.*" = "talk";
        "org.a11y.Bus" = "talk";

        "org.freedesktop.Notifications" = "talk";
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
            (envSuffix "XDG_RUNTIME_DIR" "/doc")
            (sloth.concat' sloth.xdgConfigHome "/gtk-2.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
            (sloth.concat' sloth.xdgConfigHome "/fontconfig")
          ];
          rw = [
            (envSuffix "XDG_RUNTIME_DIR" "/bus")

            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/pipewire-0")
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/speech-dispatcher")
            sloth.xdgDownloadDir
            (sloth.concat' sloth.xdgConfigHome "/vesktop")

            # This is the correct way to bind the Wayland socket.
            # The duplicate below is removed.
            (sloth.concat [
              (sloth.env "XDG_RUNTIME_DIR")
              "/"
              (sloth.envOr "WAYLAND_DISPLAY" "no")
            ])

            (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")

            # This is a bit redundant if you have sloth.xdgCacheHome already,
            # but keeping it for clarity.
            [
              (envSuffix "HOME" "/.var/app/${flatpak.appId}/cache")
              sloth.xdgCacheHome
            ]

            (envSuffix "XDG_RUNTIME_DIR" "/at-spi/bus")
            (envSuffix "XDG_RUNTIME_DIR" "/gvfsd")
          ];
          dev = [
            "/dev/dri"
            "/dev/video0"
          ];
        };

        env = {
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
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
