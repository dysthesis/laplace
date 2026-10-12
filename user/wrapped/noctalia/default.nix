{
  pkgs,
  lib,
  noctalia,
  config,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  colors = import ../../../system/display/servers/wayland/desktop/palette.nix;
  theme = {
    dark = {
      terminal = {
        background = colors.background;
        foreground = colors.foreground;
        cursor = colors.foreground;
        cursorText = colors.background;
        selectionBg = colors.focus;
        selectionFg = colors.background;

        normal = {
          black = colors.inset;
          red = colors.urgent;
          green = colors.success;
          yellow = colors.caution;
          blue = colors.focus;
          magenta = colors.warning;
          cyan = colors.info;
          white = colors.muted;
        };

        bright = {
          black = colors.dim;
          red = colors.urgent;
          green = colors.success;
          yellow = colors.warning;
          blue = colors.focus;
          magenta = colors.warning;
          cyan = colors.info;
          white = colors.foreground;
        };
      };
      mPrimary = colors.focus;
      mOnPrimary = colors.background;

      mSecondary = colors.info;
      mOnSecondary = colors.background;

      mTertiary = colors.success;
      mOnTertiary = colors.background;

      mError = colors.urgent;
      mOnError = colors.foreground;

      mSurface = colors.background;
      mOnSurface = colors.foreground;

      mSurfaceVariant = colors.surface;
      mOnSurfaceVariant = colors.muted;

      mOutline = colors.border;
      mShadow = colors.inset;

      mHover = colors.popup;
      mOnHover = colors.foreground;
    };
  };
  themeFile = pkgs.writers.writeJSON "Minimal.json" theme;
  cfg =
    import ./config.nix {
      vicinaeExe = lib.getExe pkgs.configured.vicinae;
      swaylockExe = lib.getExe pkgs.configured.swaylock;
      inherit config;
      # Avoid a dependency cycle through the configured Niri shell bindings.
      niriExe = lib.getExe pkgs.niri;
    }
    |> pkgs.writers.writeTOML "config.toml"
    |> (file:
      pkgs.runCommand "noctalia-config" {} ''
              mkdir -p "$out/noctalia"
              ln -s ${file} "$out/noctalia/config.toml"
        mkdir "$out/noctalia/palettes/"
        ln -s ${themeFile} "$out/noctalia/palettes/Minimal.json"
      '');
in
  mkWrapper pkgs noctalia {
    set.NOCTALIA_CONFIG_HOME = "${cfg}";
  }
