{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (builtins) elem;
  inherit (pkgs.stdenv.hostPlatform) system;
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit (pkgs) lib;
    inherit pkgs;
  };
  # Zen already enables --enable-replace-malloc upstream, but with
  # system-wide hardened_malloc on AMD it still crashes in
  # radeonsi/libgallium/libLLVM. Route GL through Zink/RADV instead.
  useZinkForHardenedMalloc =
    elem "malloc" config.laplace.harden
    && elem "amd" config.laplace.hardware.gpu;
in
  mkNixPak {
    config = {sloth, ...}: {
      app.package = inputs.zen-browser.packages.${system}.default;
      app.extraEntrypoints = [
        "/bin/zen-beta"
      ];
      flatpak.appId = "app.zen_browser.zen";
      etc.sslCertificates.enable = true;
      fonts = {
        enable = true;
        fonts = config.fonts.packages;
      };
      gpu.enable = true;
      locale.enable = true;
      dbus.policies = {
        "org.mozilla.*" = "own";
        "org.mpris.MediaPlayer2.firefox.*" = "own";
        "org.freedesktop.DBus" = "talk";
        "org.freedesktop.DBus.*" = "talk";
        "org.freedesktop.Notifications" = "talk";
        "org.freedesktop.ScreenSaver" = "talk";
        "org.freedesktop.portal" = "talk";
        "org.freedesktop.portal.*" = "talk";
        "org.freedesktop.NetworkManager" = "talk";
        "org.freedesktop.FileManager1" = "talk";
        "org.freedesktop.UPower" = "talk";
      };
      timeZone = {
        enable = true;
        provider = "bundle";
        zone = config.time.timeZone;
      };
      bubblewrap = {
        network = true;
        sockets = {
          wayland = lib.mkDefault (builtins.elem "wayland" config.laplace.display.servers);
          x11 = lib.mkDefault (builtins.elem "xorg" config.laplace.display.servers);
          pulse = true;
        };
        bind = {
          dev = ["/dev"];
          rw = [
            (sloth.concat' sloth.xdgCacheHome "/fontconfig")
            (sloth.concat [
              (sloth.env "XDG_RUNTIME_DIR")
              "/"
              (sloth.envOr "WAYLAND_DISPLAY" "no")
            ])
            (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")

            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/gnupg")
            (sloth.concat' (sloth.env "XDG_RUNTIME_DIR") "/pcscd")

            (sloth.concat' sloth.xdgConfigHome "/zen")
            (sloth.concat' sloth.homeDir "/.zen")
            (sloth.concat' sloth.homeDir "/Downloads")
            (sloth.concat' sloth.runtimeDir "/bus")
            (sloth.concat' sloth.runtimeDir "/dconf")
            (sloth.concat' sloth.runtimeDir "/doc")
            (sloth.mkdir (sloth.concat' sloth.xdgDownloadDir "/zen"))
          ];
          ro = [
            "/etc/localtime"
            (sloth.concat' sloth.xdgConfigHome "/gtk-2.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
            (sloth.concat' sloth.xdgConfigHome "/dconf")
            [
              "${inputs.zen-browser.packages.${system}.default}/lib/firefox"
              "/app/etc/firefox"
            ]
          ];
        };

        env = let
          cursorPackage = pkgs.bibata-cursors;
          gtkPackage = pkgs.graphite-gtk-theme.override {
            tweaks = [
              "black"
              "rimless"
              "float"
            ];
          };
        in
          {
            GTK_USE_PORTAL = "1";
            XDG_DATA_DIRS = lib.makeSearchPath "share" [
              pkgs.shared-mime-info
              cursorPackage
              gtkPackage
            ];
            XCURSOR_PATH = lib.concatStringsSep ":" [
              "${cursorPackage}/share/icons"
              "${cursorPackage}/share/pixmaps"
            ];
          }
          // lib.optionalAttrs useZinkForHardenedMalloc {
            MESA_LOADER_DRIVER_OVERRIDE = "zink";
          };
      };
    };
  }
