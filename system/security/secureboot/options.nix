{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.security.secure-boot.enable = mkEnableOption "Whether or not to enable secure boot.";
}
