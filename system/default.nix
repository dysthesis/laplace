{
  inputs,
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
    security = {
      # For electron stuff
      chromiumSuidSandbox.enable = true;
      unprivilegedUsernsClone = true;

      # `login` means TTY login
      pam.services.login.enableGnomeKeyring = true;
    };

    fonts.packages = with pkgs;
    with inputs.babel.packages.${system}; [
      noto-fonts
      noto-fonts-extra
      noto-fonts-emoji
      noto-fonts-cjk-sans
      terminus_font
      jbcustom-nf
      sf-pro
      georgia-fonts
    ];

    system.stateVersion = "24.11";

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
  };
  imports = importInDirectory ./.;
}
