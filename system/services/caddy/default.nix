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

    acme.cloudflareDns01 = {
      enable = mkEnableOption "Cloudflare DNS-01 ACME challenges";

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Environment file containing Cloudflare credentials for lego, for example CF_DNS_API_TOKEN.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.acme.cloudflareDns01.enable || cfg.acme.cloudflareDns01.environmentFile != null;
        message = "laplace.services.caddy.acme.cloudflareDns01.enable requires environmentFile.";
      }
    ];

    services.caddy = {
      enable = true;
      enableReload = true;
      openFirewall = true;
      inherit (cfg) email;
    };

    security.acme = mkIf cfg.acme.cloudflareDns01.enable {
      acceptTerms = true;
      defaults = {
        inherit (cfg) email;
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        environmentFile = cfg.acme.cloudflareDns01.environmentFile;
      };
    };
  };
}
