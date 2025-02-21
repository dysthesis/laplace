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
    ];
  laplace = {
    zram.enable = true;
    network = {
      wifi.enable = true;
      optimise = true;
    };
  };

  isoImage.edition = mkForce "erebus";

  boot.tmp.useTmpfs = mkForce false;
}
