{lib, ...}: let
  inherit (lib) mkDefault;
  inherit (lib.laplace.modules) importInDirectory;
in {
  imports = importInDirectory ./.;
  config.services.fwupd.enable = mkDefault true;
}
