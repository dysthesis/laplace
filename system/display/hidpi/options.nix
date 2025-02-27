{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.display.hidpi = mkEnableOption "Whether or not to enable HiDPI support";
}
