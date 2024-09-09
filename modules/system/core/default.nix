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
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
  services.gnome.gnome-keyring.enable = true;

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

  environment.loginShellInit = /*sh*/''
    dbus-update-activation-environment --systemd DISPLAY
    eval $(gnome-keyring-daemon --start)
    eval $(ssh-agent)
  '';

  fonts.packages = with pkgs; [
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk
  ];
}
