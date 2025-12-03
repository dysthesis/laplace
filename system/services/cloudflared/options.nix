{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.services.cloudflared.enable = mkEnableOption "Whether or not to enable cloudflared";
}
