{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.traefik.enable = mkEnableOption "Whether or not to enable Traefik";
}