{
  lib,
  modulesPath,
  ...
}:
{
  imports =
    let
      cd-drv = "installation-cd-minimal";
    in
    [ "${modulesPath}/installer/cd-dvd/${cd-drv}.nix" ];

  installer.cloneConfig = lib.mkForce false;
}
