{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.display.servers;
in
{
  config = mkIf (elem "xorg" cfg) {
    services.xserver = {
      enable = true;
      displayManager.startx.enable = true;
      excludePackages = with pkgs; [
        xterm
      ];
      xrandrHeads = map (curr: {
        inherit (curr) primary;
        output = curr.name;
        monitorConfig = ''
          Option "PreferredMode" "${toString curr.width}x${toString curr.height}_${toString curr.refreshRate}.00"
          Option "Position" "${toString curr.pos.x} ${toString curr.pos.y}"
        '';
      }) config.laplace.hardware.monitors;
    };

    services.redshift.enable = true;
  };
}
