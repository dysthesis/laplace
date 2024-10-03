{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.openbooks.enable = mkEnableOption "Whether or not to enable Traefik.";
}
