{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.forgejo.enable = mkEnableOption "Whether or not to enable Traefik.";
}
