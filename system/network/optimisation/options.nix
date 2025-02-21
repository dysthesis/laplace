{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.network.optimise = mkEnableOption "Whether or not to enable networking optimisations";
}
