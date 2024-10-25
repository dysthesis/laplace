{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.firefly-iii.enable = mkEnableOption "Whether or not to enable Firefly III";
}
