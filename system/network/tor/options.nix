{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.network.tor = {
    enable = mkEnableOption "Whether or not to enable Tor";
    libera-chat-map.enable = mkEnableOption "Whether or not to enable address mapping to access Libera chat via Tor";
  };
}
