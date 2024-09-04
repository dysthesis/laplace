{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.virtualisation.enable = mkEnableOption "Whether or not to enable virtualisation capabilities";
}
