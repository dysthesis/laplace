{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.laplace.network.dnscrypt-proxy.enable =
    mkEnableOption "Whether or not to enable DNSCrypt-Proxy";
}
