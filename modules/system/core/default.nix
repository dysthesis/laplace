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
}
