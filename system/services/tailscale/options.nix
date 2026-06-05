{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.services.tailscale.enable = mkEnableOption "Whether or not to enable Tailscale";
}
