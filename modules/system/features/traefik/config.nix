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
            httpChallenge.entryPoint = "web";
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
          http = {
            routers =
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
                  tls = {
                    domains = [{main = "*.dysthesis.com";}];
                    certresolver = "default";
                  };
                };
              };
          };
        }
        // mkIf config.laplace.features.miniflux.enable {
          services.miniflux.loadBalancer.servers = [{url = "http://${config.services.miniflux.config.LISTEN_ADDR}";}];
        };
    };
  };
}
