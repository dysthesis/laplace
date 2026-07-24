{
  modulesPath,
  pkgs,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkForce recursiveUpdate;
  system = pkgs.stdenv.hostPlatform.system;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4Rfg1TJZb861LSAJZn1xKNO1PXf7Oz2Mucq//9Dr9s demiurge@phobos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUPaVrhCJ8fDKDYCcIeICgCv6W+0GdGmMDrngIg1oKg demiurge@deimos"
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
        # The hardened kernel is panic-prone on the installer.
        harden = [];
      };
      # The ISO cannot decrypt SOPS; keep root locked and use the nixos account.
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
        # A shallow merge would discard keys for earlier users.
        curr: acc: recursiveUpdate acc {users.users.${curr}.openssh.authorizedKeys.keys = keys;}
      ) {}
      users);
}
