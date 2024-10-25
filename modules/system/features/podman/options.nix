{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.podman.enable = mkEnableOption "Whether or not to enable Podman.";
}
