{
  config,
  lib,
  ...
}: let
  inherit (lib) mkAliasOptionModule mkEnableOption mkIf mkOption types;
  cfg = config.laplace.services.caddy;
in {
  imports = [
    (mkAliasOptionModule ["laplace" "services" "caddy" "virtualHosts"] ["services" "caddy" "virtualHosts"])
  ];

  options.laplace.services.caddy = {
    enable = mkEnableOption "Caddy reverse proxy";

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Email address used for ACME account registration.";
    };
  };

  config = mkIf cfg.enable {
    # Caddy manages its own certs, obtaining them automatically via HTTP-01 /
    # TLS-ALPN-01 over the firewalled ports below; NixOS `security.acme` (lego)
    # does not apply to it. This needs inbound :443 reachable (it is, via the
    # edge port-forward). Switch to DNS-01 (caddy.withPlugins cloudflare) only
    # if you put Cloudflare's proxy in front or want wildcard certs.
    services.caddy = {
      enable = true;
      enableReload = true;
      openFirewall = true;
      inherit (cfg) email;
    };
  };
}
