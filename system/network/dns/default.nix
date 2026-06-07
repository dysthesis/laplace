{lib, ...}: let
  inherit (lib) mkDefault mkEnableOption;
in {
  imports = [./config.nix];

  options.laplace.network.dnscrypt-proxy.enable =
    mkEnableOption "Whether or not to enable DNSCrypt-Proxy";

  config.networking.nameservers = mkDefault [
    "1.1.1.1"
    "1.0.0.1"
  ];
}
