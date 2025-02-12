{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.virtualisation.enable = mkEnableOption "Whether or not to enable virtualisation capabilities";
}
