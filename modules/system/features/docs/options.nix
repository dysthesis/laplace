{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.docs.enable = mkEnableOption "Whether to build documentations.";
}
