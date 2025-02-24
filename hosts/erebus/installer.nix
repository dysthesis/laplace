{
  lib,
  modulesPath,
  ...
}:
{
  imports =
    let
      cd-drv = "installation-cd-graphical-calamares-plasma6";
    in
    [ "${modulesPath}/installer/cd-dvd/${cd-drv}.nix" ];

  installer.cloneConfig = lib.mkForce false;
}
