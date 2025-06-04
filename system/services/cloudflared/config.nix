{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.services.cloudflared;
in
{
  config = mkIf cfg.enable {
    sops.secrets = mkIf (config.networking.hostName == "erebus") {
      "cloudflared/erebus" = { };
    };
    services.cloudflared = {
      inherit (cfg) enable;
      tunnels = mkIf (config.networking.hostName == "erebus") {
        "be7bac47-ff39-43a4-bf20-aec6747775ef" = {
          credentialsFile = config.sops.secrets."cloudflared/erebus".path;
          default = "http_status:404";
        };
      };
    };
  };
}
