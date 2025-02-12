{
  lib,
  modulesPath,
  ...
}: {
  imports = let
    cd-drv = "installation-cd-graphical-gnome";
  in ["${modulesPath}/installer/cd-dvd/${cd-drv}.nix"];

  installer.cloneConfig = lib.mkForce false;
}
