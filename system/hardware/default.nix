{lib, ...}: let
  inherit (lib) mkDefault;
  inherit (lib.babel.modules) importInDirectory;
in {
  imports = importInDirectory ./.;
  config.services.fwupd.enable = mkDefault true;
}
