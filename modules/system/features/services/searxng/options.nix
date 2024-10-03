{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.searxng.enable = mkEnableOption "Whether or not to enable the SearxNG meta-search engine";
}
