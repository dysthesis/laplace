{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    ;
  inherit (builtins) elem;
  cfg = config.laplace.display.servers;
in {
  config = mkIf (elem "wayland" cfg) {
    programs.niri = {
      enable = true;
      package = pkgs.configured.niri;
      useNautilus = false;
    };
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
