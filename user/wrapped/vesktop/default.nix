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
      app.package = pkgs.unstable.vesktop;
      flatpak.appId = "dev.vencord.Vesktop";

      dbus.enable = true;

      gpu = {
        enable = true;
        provider = "bundle";
      };

      dbus.policies = {
        "org.kde.StatusNotifierWatcher" = "talk"; # Show the system tray icon.
        "${flatpak.appId}" = "own";
        "org.freedesktop.DBus" = "talk";
        "org.gtk.vfs.*" = "talk";
        "ca.desrt.dconf" = "talk";
        "org.freedesktop.portal.Desktop" = "talk";
        "org.freedesktop.portal.FileChooser" = "talk";
        "org.a11y.Bus" = "talk"; # Let accessibility tools connect.
      };

      fonts = {
        enable = true;
        fonts = config.fonts.packages;
      };

      locale.enable = true;
      etc.sslCertificates.enable = true;

      timeZone = {
        enable = true;
        provider = "bundle";
        zone = "Australia/Sydney";
      };

      bubblewrap = {
        network = true;
        shareIpc = true;
        sockets = {
          wayland = lib.mkDefault (builtins.elem "wayland" config.laplace.display.servers);
          x11 = lib.mkDefault (builtins.elem "xorg" config.laplace.display.servers);
          pulse = lib.mkDefault true;
        };
        bind = {
          ro = [
            sloth.xdgVideosDir
            sloth.xdgPicturesDir
            "/run/dbus/system_bus_socket"
            "/etc/resolv.conf"
            (envSuffix "XDG_RUNTIME_DIR" "/doc")
            (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
            (sloth.concat' sloth.xdgConfigHome "/fontconfig")
          ];
          rw = [
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/pipewire-0")
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/speech-dispatcher")
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/gnupg")
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/pcscd")
            (envSuffix "XDG_RUNTIME_DIR" "/at-spi/bus")
            (envSuffix "XDG_RUNTIME_DIR" "/gvfsd")

            sloth.xdgDownloadDir

            (sloth.concat' sloth.xdgConfigHome "/vesktop")
            # Electron stores its profile in VencordDesktop.
            (sloth.concat' sloth.xdgConfigHome "/VencordDesktop")
            (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")
            [
              (envSuffix "HOME" "/.var/app/${flatpak.appId}/cache")
              sloth.xdgCacheHome
            ]

            (sloth.concat [
              (sloth.env "XDG_RUNTIME_DIR")
              "/"
              (sloth.envOr "WAYLAND_DISPLAY" "wayland-0")
            ])
          ];
          dev = ["/dev"];
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
