{
  config,
  lib,
  ...
}: let
  inherit (lib) mkAliasOptionModule mkEnableOption mkIf;
  cfg = config.laplace.services.cloudflared;
in {
  imports = [
    (mkAliasOptionModule ["laplace" "services" "cloudflared" "tunnels"] ["services" "cloudflared" "tunnels"])
  ];

  options.laplace.services.cloudflared.enable = mkEnableOption "Whether or not to enable cloudflared";

  config = mkIf cfg.enable {
    services.cloudflared.enable = true;
  };
}
