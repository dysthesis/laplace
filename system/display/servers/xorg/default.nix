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
