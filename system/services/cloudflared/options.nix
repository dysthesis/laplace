{lib, ...}: let
  inherit (lib) mkAliasOptionModule mkEnableOption;
in {
  imports = [
    (mkAliasOptionModule ["laplace" "services" "cloudflared" "tunnels"] ["services" "cloudflared" "tunnels"])
  ];

  options.laplace.services.cloudflared.enable = mkEnableOption "Whether or not to enable cloudflared";
}
