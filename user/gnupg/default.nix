{pkgs, ...}: {
  services.udev.packages = [pkgs.yubikey-personalization];
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
