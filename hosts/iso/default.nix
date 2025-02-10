{
  inputs,
  pkgs,
  modulesPath,
  ...
}: {
  imports = let
    cd-drv = "installation-cd-graphical-calamares-plasma6";
  in ["${modulesPath}/installer/cd-dvd/${cd-drv}.nix"];
  # Use the latest kernel packages!
  boot.kernelPackages = pkgs.linuxPackages_latest;
  environment.systemPackages = [
    inputs.poincare.packages.${pkgs.system}.default
    inputs.daedalus.packages.${pkgs.system}.default
  ];
}
