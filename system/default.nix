{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  config = {
    # services = {
    #   gnome.gnome-keyring.enable = true;
    #   dbus = {
    #     packages = with pkgs; [
    #       dconf
    #       gcr
    #       udisks2
    #     ];
    #     implementation = "broker";
    #     enable = true;
    #   };
    # };
    # security = {
    #   # For electron stuff
    #   chromiumSuidSandbox.enable = true;
    #   unprivilegedUsernsClone = true;
    #
    #   # `login` means TTY login
    #   pam.services.login.enableGnomeKeyring = true;
    # };
    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
  };
  imports = importInDirectory ./.;
}
