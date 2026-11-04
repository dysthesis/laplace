{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types mapAttrs;
  cfg = config.laplace.services.caddy;
in {
  options.laplace.services.caddy = {
    enable = mkEnableOption "Caddy reverse proxy";

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Email address used for ACME account registration.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open 80/443 in the host firewall. Set false on tailnet-only nodes: the
        tailscale module already trusts tailscale0, so :443 is reachable over the
        tailnet without exposing it on the LAN.'';
    };

    # Use DNS-01 for internal names because Let's Encrypt cannot reach them.
    cloudflare = {
      enable = mkEnableOption "DNS-01 certificates via Cloudflare";

      sopsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = lib.literalExpression "../../system/secrets/cloudflare.yaml";
        description = "sops file holding the Cloudflare API token (key `secretName`). This node's age key must be a recipient.";
      };

      secretName = mkOption {
        type = types.str;
        default = "cloudflare_api_key";
        description = "Key within `sopsFile` holding a Cloudflare token scoped to Zone:DNS:Edit on the zone.";
      };

      proxies = mkOption {
        type = types.attrsOf types.str;
        default = {};
        example = {"immich.dysthesis.com" = "localhost:2283";};
        description = ''
          hostname -> upstream. Each becomes an HTTPS vhost with a DNS-01 cert and
          a reverse_proxy. Upstreams are local (this Caddy runs on the app's node),
          e.g. "localhost:2283".'';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.caddy = {
        enable = true;
        enableReload = true;
        inherit (cfg) email openFirewall;
      };
      # Persist ACME state to prevent reissue rate-limit errors.
      mnemosyne.dirs = ["/var/lib/caddy"];
    }

    (mkIf cfg.cloudflare.enable {
      assertions = [
        {
          assertion = cfg.cloudflare.sopsFile != null;
          message = "laplace.services.caddy.cloudflare.enable needs cloudflare.sopsFile (the sops file with the Cloudflare token, encrypted to this host's age key).";
        }
      ];

      # Update the Cloudflare plugin version and hash together.
      services.caddy.package = pkgs.caddy.withPlugins {
        plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
        hash = "sha256-xRJ5evsAJ2akg47j3Bt6YDXJOgX88B/rKNP50KSVyNY=";
      };

      # Use public DNS for ACME challenge lookups.
      # Caddy 2.11 can buffer encoded server-sent events. Do not encode EventSource streams.
      services.caddy.virtualHosts =
        mapAttrs (_host: upstream: {
          extraConfig = ''
            tls {
              dns cloudflare {env.CF_API_TOKEN}
              resolvers 1.1.1.1
            }
            @notSSE not header Accept *text/event-stream*
            encode @notSSE
            reverse_proxy ${upstream}
          '';
        })
        cfg.cloudflare.proxies;

      # Keep the token in a runtime EnvironmentFile, outside the store.
      sops = {
        secrets.${cfg.cloudflare.secretName} = {
          sopsFile = cfg.cloudflare.sopsFile;
          restartUnits = ["caddy.service"];
        };
        templates."caddy-cloudflare.env".content = "CF_API_TOKEN=${config.sops.placeholder.${cfg.cloudflare.secretName}}";
      };
      systemd.services.caddy.serviceConfig.EnvironmentFile =
        config.sops.templates."caddy-cloudflare.env".path;
    })
  ]);
}
