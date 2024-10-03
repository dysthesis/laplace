{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.miniflux.enable = mkEnableOption "Whether or not to enable the Miniflux RSS feed reader";
}
