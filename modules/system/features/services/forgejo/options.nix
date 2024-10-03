{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.forgejo.enable = mkEnableOption "Whether or not to enable Traefik.";
}
