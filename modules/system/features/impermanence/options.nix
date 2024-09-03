{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.impermanence.enable = mkEnableOption "Whether or not to enable impermanence";
}
