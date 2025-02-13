{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.security.apparmor.enable = mkEnableOption "Whether or not to enable AppArmor.";
}
