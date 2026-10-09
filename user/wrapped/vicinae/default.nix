{
  pkgs,
  lib,
  vicinae ? pkgs.vicinae,
  ...
}: let
  palette = import ../../../system/display/servers/wayland/desktop/palette.nix;
  themeFile = (pkgs.formats.toml {}).generate "laplace-minimal.toml" {
    meta = {
      name = "Laplace Minimal";
      description = "Opaque minimal.nvim desktop palette";
      variant = "dark";
      inherits = "vicinae-dark";
    };
    colors = {
      core = {
        accent = palette.focus;
        accent_foreground = palette.foreground;
        background = palette.popup;
        foreground = palette.foreground;
        secondary_background = palette.surface;
        border = palette.border;
      };
      main_window = {
        border = palette.border;
        footer.background = palette.surface;
      };
      settings_window.border = palette.border;
      accents = {
        blue = palette.focus;
        green = palette.success;
        magenta = palette.info;
        orange = palette.warning;
        red = palette.urgent;
        yellow = palette.caution;
        cyan = palette.info;
        purple = palette.info;
      };
      shortcut.border = palette.border;
      text = {
        default = palette.foreground;
        muted = palette.muted;
        danger = palette.foreground;
        success = palette.foreground;
        placeholder = palette.dim;
        selection = {
          background = palette.border;
          foreground = palette.foreground;
        };
        links = {
          default = palette.muted;
          visited = palette.dim;
        };
      };
      input = {
        background = palette.inset;
        border = palette.border;
        border_focus = palette.focus;
        border_error = palette.urgent;
      };
      button.primary = {
        background = palette.surface;
        foreground = palette.foreground;
        hover = {
          background = palette.border;
          foreground = palette.foreground;
        };
        focus.outline = palette.focus;
      };
      list.item = {
        hover = {
          background = palette.surface;
          foreground = palette.foreground;
          secondary_foreground = palette.muted;
        };
        selection = {
          background = palette.surface;
          foreground = palette.foreground;
          secondary_background = palette.surface;
          secondary_foreground = palette.muted;
        };
      };
      grid.item = {
        background = palette.surface;
        hover.outline = palette.border;
        selection.outline = palette.focus;
      };
      scrollbars = {
        background = palette.border;
        secondary_background = palette.surface;
      };
      tooltip = {
        background = palette.popup;
        foreground = palette.foreground;
        border = palette.border;
      };
      loading = {
        bar = palette.focus;
        spinner = palette.muted;
      };
    };
  };
  defaultsFile = pkgs.writeText "vicinae-desktop-defaults.json" (builtins.toJSON {
    search_files_in_root = false;
    fallbacks = [];
    providers.files.preferences.autoIndexing = false;
    font = {
      rendering = "native";
      normal = {
        family = "Atkinson Hyperlegible Next";
        size = 10;
      };
    };
    theme = {
      light.name = "laplace-minimal";
      dark.name = "laplace-minimal";
    };
    launcher_window = {
      opacity = 1;
      material = "none";
      blur.enabled = false;
      rounding = 10;
      client_side_decorations = {
        enabled = true;
        border_width = 1;
        shadow_size = 0;
      };
    };
  });
  initialSettings = pkgs.writeText "vicinae-desktop-settings.json" (builtins.toJSON {
    imports = ["defaults.json"];
  });
  assets = pkgs.runCommand "vicinae-desktop-assets" {} ''
    mkdir -p "$out/share/vicinae/themes"
    ln -s ${themeFile} "$out/share/vicinae/themes/laplace-minimal.toml"
  '';
  bootstrap = ''
    export XDG_DATA_DIRS="${assets}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    if [ "''${1-}" = server ]; then
      prepare=1
      for argument in "$@"; do
        case "$argument" in
          --config|--config=*|-h|--help) prepare=0 ;;
        esac
      done
      if [ "$prepare" -eq 1 ]; then
        umask 077
        directory="''${XDG_CONFIG_HOME:-$HOME/.config}/vicinae/laplace"
        ${pkgs.coreutils}/bin/mkdir -p "$directory"
        exec 9>"$directory/.bootstrap.lock"
        ${pkgs.util-linux}/bin/flock 9
        defaults="$directory/defaults.json"
        if [ -e "$defaults" ] && [ ! -L "$defaults" ]; then
          printf 'Vicinae: refusing to replace non-symlink %s\n' "$defaults" >&2
          exit 1
        fi
        if [ -L "$defaults" ]; then
          case "$(${pkgs.coreutils}/bin/readlink "$defaults")" in
            /nix/store/*-vicinae-desktop-defaults.json) ;;
            *) printf 'Vicinae: refusing to replace unowned symlink %s\n' "$defaults" >&2; exit 1 ;;
          esac
        fi
        ${pkgs.coreutils}/bin/ln -sfnT ${defaultsFile} "$defaults"
        settings="$directory/settings.json"
        if [ ! -e "$settings" ] && [ ! -L "$settings" ]; then
          (set -C; ${pkgs.coreutils}/bin/cat ${initialSettings} > "$settings")
        fi
        if [ -L "$settings" ] || [ ! -f "$settings" ] || [ ! -w "$settings" ]; then
          printf 'Vicinae: settings must be a writable regular file: %s\n' "$settings" >&2
          exit 1
        fi
        exec 9>&-
        shift
        set -- server --config "$settings" "$@"
      fi
    fi
  '';
in
  (lib.laplace.pkgs.mkWrapper pkgs vicinae {
    binPath = [pkgs.pulseaudio];
    run = [bootstrap];
    postBuild = ''
      for entry in vicinae vicinae-url-handler; do
        desktopFile="$out/share/applications/$entry.desktop"
        desktopTarget=$(readlink -f "$desktopFile")
        rm "$desktopFile"
        cp "$desktopTarget" "$desktopFile"
        substituteInPlace "$desktopFile" \
          --replace-fail 'Exec=vicinae' "Exec=$out/bin/vicinae"
      done
      substituteInPlace "$out/share/applications/vicinae.desktop" \
        --replace-fail "Exec=$out/bin/vicinae server --replace" "Exec=$out/bin/vicinae toggle"
    '';
  }).overrideAttrs (old: {
    passthru = (old.passthru or {}) // {inherit assets defaultsFile initialSettings themeFile;};
  })
