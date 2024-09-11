{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.displayServer;
in {
  config = mkIf (cfg == "wayland") {
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
