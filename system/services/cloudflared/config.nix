{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.cloudflared;
in {
  config = mkIf cfg.enable {
    services.cloudflared.enable = true;
  };
}
