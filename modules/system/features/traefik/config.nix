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
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };
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
          web = {
            address = ":80";
            http = {
              redirections = {
                entryPoint = {
                  to = "websecure";
                  scheme = "https";
                };
              };
            };
          };
          websecure = {
            address = ":443";
            http = {
              tls = {
                options = "default";
              };
            };
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
              dashboard = {
                rule = "Host(`monitor.dysthesis.com`)";
                service = "api@internal";
                entrypoints = ["websecure"];
                tls = {
                  certResolver = "default";
                };
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
          http.services.miniflux.loadBalancer.servers = [{url = config.services.miniflux.config.LISTEN_ADDR;}];
        };
    };
  };
}
