{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.calibre-web.enable = mkEnableOption "Whether or not to enable the Calibre Web interface";
}
