{
  modulesPath,
  pkgs,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkForce recursiveUpdate;
  system = pkgs.stdenv.hostPlatform.system;
  workstationKeys = import ../../system/users/keys.nix;
  keys = [
    workstationKeys.phobosInstaller
    workstationKeys.deimos
  ];
  users = [
    "root"
    "nixos"
  ];
in {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
  ];

  config =
    recursiveUpdate {
      isoImage.edition = "chaos";
      laplace = {
        profiles = ["desktop"];
        # The hardened kernel can panic on the installer.
        harden = [];
      };
      # The ISO cannot decrypt SOPS secrets. Keep root locked and use the nixos account.
      users.users.root = {
        hashedPassword = mkForce null;
        initialHashedPassword = mkForce null;
      };
      environment.systemPackages = with pkgs; [
        configured.foot
        configured.wikiman
        configured.helix
        configured.fish
        configured.tmux

        unstable.uutils-coreutils-noprefix
        unstable.tor-browser
        unstable.sbctl
        unstable.w3m
        unstable.chawan

        inputs.zen-browser.packages.${system}.default
        inputs.poincare.packages.${system}.default
      ];
    }
    (lib.foldr (
        # A shallow merge discards keys for other users.
        curr: acc: recursiveUpdate acc {users.users.${curr}.openssh.authorizedKeys.keys = keys;}
      ) {}
      users);
}
