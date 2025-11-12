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
  niriLoginShell = pkgs.writeShellScriptBin "niri-login-shell" ''
    set -u

    if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -z "''${DISPLAY:-}" ] && [ "''${XDG_VTNR:-}" = "1" ] && [ -z "''${NIRI_SESSION_STARTED:-}" ]; then
      export NIRI_SESSION_STARTED=1
      ${lib.getExe pkgs.configured.hyprland}|| true
    fi

    exec ${pkgs.bashInteractive}/bin/bash
  '';
in {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  config =
    {
      isoImage.edition = "chaos";
      laplace = {
        profiles = ["desktop"];
        harden = ["kernel"];
      };
      environment.systemPackages = with pkgs; [
        configured.wikiman
        configured.helix
        configured.fish

        unstable.uutils-coreutils-noprefix
        unstable.tor-browser
        unstable.protonvpn-gui
        unstable.sbctl
        unstable.w3m
        unstable.chawan

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
    users;
}
