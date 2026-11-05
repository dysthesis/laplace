{
  config,
  lib,
  ...
}: let
  operation = lib.types.mkOptionType {
    name = "desktopOperation";
    description = "non-empty argument vector with an absolute executable";
    check = argv:
      builtins.isList argv
      && argv != []
      && lib.all builtins.isString argv
      && lib.hasPrefix "/" (builtins.head argv);
    merge = lib.mergeEqualOption;
  };
  configuration = lib.types.functionTo lib.types.attrs;
  factory = names: result:
    lib.types.submodule {
      options = {
        name = lib.mkOption {type = lib.types.enum names;};
        build = lib.mkOption {type = lib.types.functionTo result;};
      };
    };
in {
  imports = [
    ./servers
  ];

  options.laplace.desktop = lib.mkOption {
    default = null;
    description = "Explicit managed desktop components; requires the desktop profile.";
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        server = lib.mkOption {
          type = lib.types.submodule {
            options = {
              protocol = lib.mkOption {type = lib.types.enum ["wayland" "x11"];};
              configure = lib.mkOption {type = configuration;};
            };
          };
        };
        wm = lib.mkOption {
          type = lib.types.submodule {
            options = {
              name = lib.mkOption {type = lib.types.enum ["niri" "hyprland" "sway" "river" "dwl" "xmonad"];};
              protocol = lib.mkOption {type = lib.types.enum ["wayland" "x11"];};
              configure = lib.mkOption {type = configuration;};
              logout = lib.mkOption {
                type = lib.types.nullOr (lib.types.functionTo operation);
                default = null;
              };
            };
          };
        };
        term = lib.mkOption {type = factory ["foot"] lib.types.attrs;};
        launcher = lib.mkOption {
          type = lib.types.nullOr (factory ["vicinae" "fuzzel"] lib.types.attrs);
          default = null;
        };
        bar = lib.mkOption {
          type = lib.types.nullOr (factory ["waybar"] lib.types.package);
          default = null;
        };
        shell = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              name = lib.mkOption {type = lib.types.enum ["noctalia"];};
              build = lib.mkOption {type = lib.types.functionTo lib.types.package;};
              configure = lib.mkOption {type = configuration;};
            };
          });
          default = null;
        };
      };
    });
    apply = desktop:
      if desktop == null
      then null
      else
        assert lib.assertMsg (builtins.elem "desktop" config.laplace.profiles)
        "laplace.desktop requires the desktop profile.";
        assert lib.assertMsg (desktop.server.protocol == desktop.wm.protocol)
        "laplace.desktop.server and wm must use the same display protocol.";
        assert lib.assertMsg (
          if desktop.wm.name == "niri"
          then
            desktop.launcher
            != null
            && (
              if desktop.shell != null
              then desktop.launcher.name == "vicinae" && desktop.wm.logout != null
              else desktop.launcher.name == "fuzzel" && desktop.bar != null
            )
          else desktop.shell == null && desktop.bar == null && desktop.launcher == null
        ) "Niri requires Noctalia/Vicinae or Waybar/Fuzzel; legacy WMs retain their own shell, bar and launcher."; desktop;
  };

  options.laplace.wm = lib.mkOption {
    readOnly = true;
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        protocol = lib.mkOption {type = lib.types.enum ["wayland" "x11"];};
        login = lib.mkOption {type = operation;};
        logout = lib.mkOption {
          type = lib.types.nullOr operation;
          default = null;
        };
      };
    });
    description = "Selected managed session operations; configure laplace.desktop instead.";
  };

  options.laplace.display = {
    foot.fontSize = lib.mkOption {
      type = lib.types.oneOf [lib.types.int lib.types.float];
      default = 9.5;
      description = "Foot font size in points.";
    };
    fuzzel.fontSize = lib.mkOption {
      type = lib.types.oneOf [lib.types.int lib.types.float];
      default = 11.5;
      description = "Fuzzel font size in points.";
    };
  };
}
