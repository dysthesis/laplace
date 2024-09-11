{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (builtins)
    any
    attrNames
    ;
  inherit
    (lib)
    mkForce
    mkDefault
    mkIf
    filterAttrs
    ;

  enabledUsers =
    attrNames
    (filterAttrs
      (_name: value: (value.enable && value.useHomeManager))
      config.laplace.users);

  hasHyprland = user: config.home-manager.users.${user}.wayland.windowManager.hyprland.enable;
in {
  # No default packages. From https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
  environment.defaultPackages = mkForce [];
  imports = [
    ./hardware
    ./boot
    ./network
    ./nix
    ./security
    ./sound
    ./users
  ];

  # TODO: Refactor these and find better places to put them
  programs = mkIf (config.networking.hostName != "astaphaios") ({
      gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-gnome3;
      };
    }
    // mkIf (any hasHyprland enabledUsers) {hyprlock.enable = true;});

  services = {
    gnome.gnome-keyring.enable = true;
    dbus = {
      packages = with pkgs; [dconf gcr udisks2];
      implementation = "broker";
      enable = true;
    };
  };

  xdg.portal = mkIf (any hasHyprland enabledUsers) {
    enable = true;
    wlr.enable = mkDefault false;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
    ];
  };
  # Enable hyprlock PAM (and gnome-keyring integration)
  security = mkIf (any hasHyprland enabledUsers) {pam.services.hyprlock.enableGnomeKeyring = lib.mkDefault config.services.gnome.gnome-keyring.enable;};

  fonts.packages = with pkgs;
    mkIf (config.networking.hostName != "astaphaios") [
      (nerdfonts.override {fonts = ["JetBrainsMono"];})
      noto-fonts
      noto-fonts-emoji
      noto-fonts-cjk
      font-awesome
    ];
}
