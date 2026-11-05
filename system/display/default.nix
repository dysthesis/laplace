{lib, ...}: let
  operation =
    lib.types.addCheck (lib.types.nonEmptyListOf lib.types.str)
    (argv: lib.hasPrefix "/" (builtins.head argv));
in {
  imports = [
    ./servers
  ];

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
    description = "Selected managed session operations; selection belongs to the host assembly.";
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
