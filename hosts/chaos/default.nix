{
  modulesPath,
  pkgs,
  inputs,
  lib,
  ...
}: let
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4Rfg1TJZb861LSAJZn1xKNO1PXf7Oz2Mucq//9Dr9s demiurge@phobos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUPaVrhCJ8fDKDYCcIeICgCv6W+0GdGmMDrngIg1oKg demiurge@deimos"
  ];
  users = [
    "root"
    "nixos"
  ];
in
  {
    imports = [
      "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix"
    ];

    laplace = {
      profiles = [ "desktop" ];
      harden = [ "kernel" ];
      display.servers = [ "wayland" ];
    };

    programs.niri = {
      enable = true;
      package = pkgs.configured.niri;
    };

    services.displayManager = {
      defaultSession = "niri";
      gdm = {
        enable = true;
        autoSuspend = false;
      };
      autoLogin = {
        enable = true;
        user = "nixos";
        session = "niri";
      };
    };

    environment.systemPackages = with pkgs; [
      (configured.ghostty.override {
        withDecorations = true;
      })
      configured.wikiman
      configured.helix
      configured.fish

      unstable.uutils-coreutils-noprefix
      unstable.tor-browser
      unstable.protonvpn-gui
      unstable.sbctl

      inputs.zen-browser.packages.${pkgs.system}.default
      inputs.poincare.packages.${pkgs.system}.default
      (inputs.daedalus.packages.${pkgs.system}.default.override {
        shell = "${pkgs.configured.fish}/bin/fish";
        targets = [
          "~/Documents/Projects/"
          "~/Documents/University/"
        ];
      })
    ];
  }
  // lib.fold
  (curr: acc:
    acc
    // {users.users.${curr}.openssh.authorizedKeys.keys = keys;})
  {}
  users
