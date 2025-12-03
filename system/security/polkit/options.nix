{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.security.polkit.enable = mkEnableOption "Whether or not to enable Polkit";
}
