{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.caddy.enable = mkEnableOption "Whether or not to enable the Caddy web server";
}
