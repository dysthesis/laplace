{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  config = {
    services = {
      gnome.gnome-keyring.enable = true;
      dbus = {
        packages = with pkgs; [
          dconf
          gcr
          udisks2
        ];
        implementation = "broker";
        enable = true;
      };
    };
    security.pam.services.login.enableGnomeKeyring = true;

    system.stateVersion = "24.11";
  };
  imports = importInDirectory ./.;
}
