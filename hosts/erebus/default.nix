{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkForce;
in {
  imports = [
    ./installer.nix
  ];
  environment.systemPackages = let
    inherit
      (pkgs)
      system
      ;
  in
    with pkgs; [
      inputs.disko.packages.${system}.default
      inputs.daedalus.packages.${system}.default
      inputs.poincare.packages.${system}.default
      configured.ghostty
      (nerdfonts.override {
        fonts = ["JetBrainsMono"];
      })
      btop
      just
      microfetch
      tor-browser-bundle-bin
    ];

  networking.stevenblack.enable = true;

  laplace = {
    profiles = ["desktop"];
    harden = ["kernel"];
    zram.enable = true;
    network.optimise = true;
  };

  isoImage.edition = mkForce "erebus";

  boot.tmp.useTmpfs = mkForce false;
}
