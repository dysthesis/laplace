{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.traefik.enable;
in {
  config = mkIf cfg {
    services.traefik = {
      enable = true;

      staticConfigOptions = {
        log.level = "DEBUG";

        api.dashboard = true;
        certificatesResolvers = {
          default.acme = {
            email = "acme.dictate699@simplelogin.com";
            storage = "/var/lib/traefik/acme.json";
            caServer = "https://acme-v02.api.letsencrypt.org/directory";
            dnsChallenge = {
              provider = "cloudflare";
              resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
              delayBeforeCheck = "0";
            };
          };
        };

        entryPoints = {
          http = {
            address = ":80";
            forwardedHeaders.insecure = true;
            http.redirections.entryPoint = {
              to = "https";
              scheme = "https";
            };
          };

          https = {
            address = ":443";
            # enableHTTP3 = true;
            forwardedHeaders.insecure = true;
          };

          experimental = {
            address = ":1111";
            forwardedHeaders.insecure = true;
          };
        };
      };
      dynamicConfigOptions =
        {
          http.routers =
            {
              api = {
                entrypoints = ["traefik"];
                rule = "PathPrefix(`/api/`)";
                service = "api@internal";
              };
            }
            // mkIf config.laplace.features.miniflux.enable {
              miniflux = {
                rule = "Host(`rss.dysthesis.com`)";
                entrypoints = ["websecure"];
                service = "miniflux";
                tls.domains = [{main = "*.dysthesis.com";}];
                tls.certresolver = "default";
              };
            };
        }
        // mkIf config.laplace.features.miniflux.enable {
          http.services.miniflux.servers = [{url = "http://localhost:8085";}];
        };
    };
  };
}
