{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.security.firewall.enable = mkEnableOption "Whether or not to enable firewall";
}
