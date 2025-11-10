{
  modulesPath,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-gnome.nix"
  ];

  laplace = {
    users = [ "demiurge" ];
  };

  environment.systemPackages = with pkgs; [
    configured.ghostty
    configured.wikiman
    configured.helix
    configured.fish

    unstable.uutils-coreutils-noprefix
    unstable.tor-browser
    unstable.protonvpn-gui

    inputs.zen-browser.packages.${pkgs.system}.default
    inputs.poincare.packages.${pkgs.system}.default
    (inputs.daedalus.packages.${pkgs.system}.default.override {
      shell = "${pkgs.configured.fish}/bin/fish";
      targets = ["~/Documents/Projects/" "~/Documents/University/"];
    })
  ];
}
