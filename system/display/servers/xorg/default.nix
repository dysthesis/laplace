{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    optionalString
    ;
  inherit (builtins) elem;
  cfg = config.laplace.display.servers;
in {
  imports = [
    (lib.laplace.modules.mkSelector {
      dir = ./sessions;
      option = ["laplace" "display" "xorg" "session"];
      description = "Which X11 session to run";
      multiple = false;
      default = "xmonad";
    })
  ];

  # Selected Xorg command for VT1 login.
  options.laplace.display.xorg.sessionCommand = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    internal = true;
    description = "Command login shells exec to start the X11 session.";
  };

  config = mkIf (elem "xorg" cfg) {
    environment.systemPackages = with pkgs; [
      xclip
    ];
    services.xserver = {
      enable = true;
      displayManager.startx.enable = true;
      excludePackages = with pkgs; [
        xterm
      ];
      xrandrHeads =
        map (
          curr: let
            mkPosition = curr:
              optionalString ((curr.pos.x != null) && (curr.pos.y != null)) ''
                Option "Position" "${toString curr.pos.x} ${toString curr.pos.y}"
              '';
          in {
            inherit (curr) primary;
            output = curr.name;
            monitorConfig = ''
              Option "PreferredMode" "${toString curr.width}x${toString curr.height}_${toString curr.refreshRate}.00"
                ${mkPosition curr}
            '';
          }
        )
        config.laplace.hardware.monitors;
      deviceSection = ''Option "TearFree" "True"'';
    };

    services.redshift.enable = true;
  };
}
