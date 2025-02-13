{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.display;
in
{
  config = mkIf (cfg == "wayland") {
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
