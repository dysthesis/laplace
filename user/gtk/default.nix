{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) isBool toString;
  inherit
    (lib)
    boolToString
    generators
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;
  inherit (lib.strings) escape;
  inherit (builtins) elem;

  isDesktop = elem "desktop" config.laplace.profiles;
  cfg = config.laplace.gtk;

  toGtkIni = generators.toINI {
    mkKeyValue = key: value: let
      value' =
        if isBool value
        then boolToString value
        else toString value;
    in "${escape ["="] key}=${value'}";
  };

  gtkSettings =
    {
      gtk-theme-name = cfg.theme.name;
      gtk-icon-theme-name = cfg.iconTheme.name;
      gtk-cursor-theme-name = cfg.cursor.name;
      gtk-application-prefer-dark-theme =
        if cfg.preferDark
        then 1
        else 0;
    }
    // optionalAttrs (cfg.fontName != null) {
      gtk-font-name = cfg.fontName;
    };
in {
  options.laplace.gtk = {
    enable = (mkEnableOption "Enable GTK theming via Ariadne") // {default = true;};

    preferDark = mkOption {
      type = types.bool;
      default = true;
      description = "Whether GTK should prefer a dark colour scheme.";
    };

    fontName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional GTK font name (for example, \"Lexend 11\").";
    };

    cssText = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = "Optional gtk.css content to write for GTK 3 and GTK 4.";
    };

    theme = {
      package = mkOption {
        type = types.package;
        default = pkgs.graphite-gtk-theme;
        description = "GTK theme package to install system-wide.";
      };
      name = mkOption {
        type = types.str;
        default = "Graphite-Dark";
        description = "GTK theme name (directory name under share/themes).";
      };
    };

    iconTheme = {
      package = mkOption {
        type = types.package;
        default = pkgs.papirus-icon-theme;
        description = "Icon theme package to install system-wide.";
      };
      name = mkOption {
        type = types.str;
        default = "Papirus";
        description = "Icon theme name (directory name under share/icons).";
      };
    };

    cursor = {
      package = mkOption {
        type = types.package;
        default = pkgs.bibata-cursors;
        description = "Cursor theme package to install system-wide.";
      };
      name = mkOption {
        type = types.str;
        default = "Bibata-Modern-Classic";
        description = "Cursor theme name (directory name under share/icons).";
      };
      size = mkOption {
        type = types.int;
        default = 24;
        description = "Default XCursor size.";
      };
    };
  };

  config = mkIf (isDesktop && cfg.enable) {
    ariadne =
      {
        ".config/gtk-3.0/settings.ini".text = toGtkIni {Settings = gtkSettings;};
        ".config/gtk-4.0/settings.ini".text = toGtkIni {Settings = gtkSettings;};
      }
      // optionalAttrs (cfg.cssText != null) {
        ".config/gtk-3.0/gtk.css".text = cfg.cssText;
        ".config/gtk-4.0/gtk.css".text = cfg.cssText;
      };

    environment = {
      systemPackages = [
        cfg.theme.package
        cfg.iconTheme.package
        cfg.cursor.package
      ];

      sessionVariables = {
        XCURSOR_THEME = cfg.cursor.name;
        XCURSOR_SIZE = toString cfg.cursor.size;
      };
    };
  };
}
