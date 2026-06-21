{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkAliasOptionModule mkEnableOption mkIf mkMerge mkOption types mapAttrs;
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

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open 80/443 in the host firewall. Set false on tailnet-only nodes: the
        tailscale module already trusts tailscale0, so :443 is reachable over the
        tailnet without exposing it on the LAN.'';
    };

    # DNS-01 issuance for names with no public A record (tailnet-only
    # *.dysthesis.com). HTTP-01/TLS-ALPN can't validate a name Let's Encrypt
    # cannot reach, so a node fronting such names must prove control via DNS.
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
      # ACME account + issued certs. Persist them or impermanence drops /var/lib
      # on reboot and every deploy re-issues, burning Let's Encrypt rate limits.
      mnemosyne.dirs = ["/var/lib/caddy"];
    }

    (mkIf cfg.cloudflare.enable {
      assertions = [
        {
          assertion = cfg.cloudflare.sopsFile != null;
          message = "laplace.services.caddy.cloudflare.enable needs cloudflare.sopsFile (the sops file with the Cloudflare token, encrypted to this host's age key).";
        }
      ];

      # Stock Caddy has no `dns cloudflare`; bake the plugin in. One source of
      # truth for the plugin version + vendored-deps FOD hash (was duplicated in
      # the horos host); bump both together when the caddy/plugin version changes.
      services.caddy.package = pkgs.caddy.withPlugins {
        plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
        hash = "sha256-8yZDrejNKsaUnUaTUFYbarWNmxafqp2z2rWo+XRsxV8=";
      };

      # `resolvers 1.1.1.1` sends the ACME challenge lookups to a public resolver,
      # bypassing the tailnet DNS (which only answers the internal names).
      services.caddy.virtualHosts =
        mapAttrs (_host: upstream: {
          extraConfig = ''
            tls {
              dns cloudflare {env.CF_API_TOKEN}
              resolvers 1.1.1.1
            }
            reverse_proxy ${upstream}
          '';
        })
        cfg.cloudflare.proxies;

      # Render the token into an EnvironmentFile (a string, so it is not copied to
      # the world-readable store) and feed it to Caddy's process.
      sops = {
        secrets.${cfg.cloudflare.secretName}.sopsFile = cfg.cloudflare.sopsFile;
        templates."caddy-cloudflare.env".content = "CF_API_TOKEN=${config.sops.placeholder.${cfg.cloudflare.secretName}}";
      };
      systemd.services.caddy.serviceConfig.EnvironmentFile =
        config.sops.templates."caddy-cloudflare.env".path;
    })
  ]);
}
