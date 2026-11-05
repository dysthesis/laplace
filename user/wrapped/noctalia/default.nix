{
  pkgs,
  lib,
  noctalia,
  config,
  launcherOpen,
  logout,
  barEnabled,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  palette = import ../../../system/display/servers/wayland/desktop/palette.nix;
  theme = {
    dark = {
      terminal = {
        background = palette.background;
        foreground = palette.foreground;
        cursor = palette.foreground;
        cursorText = palette.background;
        selectionBg = palette.focus;
        selectionFg = palette.background;

        normal = {
          black = palette.inset;
          red = palette.urgent;
          green = palette.success;
          yellow = palette.caution;
          blue = palette.focus;
          magenta = palette.warning;
          cyan = palette.info;
          white = palette.muted;
        };

        bright = {
          black = palette.dim;
          red = palette.urgent;
          green = palette.success;
          yellow = palette.warning;
          blue = palette.focus;
          magenta = palette.warning;
          cyan = palette.info;
          white = palette.foreground;
        };
      };
      mPrimary = palette.focus;
      mOnPrimary = palette.background;

      mSecondary = palette.info;
      mOnSecondary = palette.background;

      mTertiary = palette.success;
      mOnTertiary = palette.background;

      mError = palette.urgent;
      mOnError = palette.foreground;

      mSurface = palette.background;
      mOnSurface = palette.foreground;

      mSurfaceVariant = palette.surface;
      mOnSurfaceVariant = palette.muted;

      mOutline = palette.border;
      mShadow = palette.inset;

      mHover = palette.popup;
      mOnHover = palette.foreground;
    };
  };
  themeFile = pkgs.writers.writeJSON "Minimal.json" theme;
  cfg =
    import ./config.nix {
      inherit lib config launcherOpen logout barEnabled;
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
  mkWrapper pkgs (
    if barEnabled
    then noctalia
    # Saved settings load after config.toml; external bar ownership must win.
    else
      noctalia.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./disable-bars.patch];
      })
  ) {
    set =
      {NOCTALIA_CONFIG_HOME = "${cfg}";}
      // lib.optionalAttrs (!barEnabled) {NOCTALIA_DISABLE_BARS = "1";};
  }
