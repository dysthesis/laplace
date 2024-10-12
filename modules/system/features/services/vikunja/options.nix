{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.vikunja.enable = mkEnableOption "Whether or not to enable the Vikunja to-do list app";
}
