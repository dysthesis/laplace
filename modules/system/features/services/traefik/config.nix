{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.traefik.enable;
in {
  config = mkIf cfg {
    sops.secrets.traefik = {};
    sops.secrets.acme = {};
    systemd.services.traefik.serviceConfig.EnvironmentFile = [config.sops.secrets.traefik.path];

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
            email = "cloudflare.crunchy685@simplelogin.com";
            storage = "/var/lib/traefik/acme.json";
            caServer = "https://acme-v02.api.letsencrypt.org/directory";
            dnsChallenge = {
              # delayBeforeCheck = 0;
              provider = "cloudflare";
              resolvers = ["1.1.1.1:53" "8.8.8.8:53"];
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
              tls.options = "default";
            };
          };
        };
      };
      dynamicConfigOptions.http = {
        routers = {
          miniflux = {
            rule = "Host(`rss.dysthesis.com`) && PathPrefix(`/`)";
            entrypoints = ["websecure"];
            service = "miniflux";
            tls = {
              domains = [{main = "*.dysthesis.com";}];
              certresolver = "default";
            };
          };
          forgejo = {
            rule = "Host(`git.dysthesis.com`)";
            entrypoints = ["websecure"];
            service = "forgejo";
            tls.domains = [{main = "*.dysthesis.com";}];
            tls.certresolver = "production";
          };
        };
        services = {
          miniflux.loadBalancer.servers = [{url = "http://${config.services.miniflux.config.LISTEN_ADDR}";}];
          forgejo.loadBalancer.servers = [{url = "http://localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}";}];
        };
      };
    };
  };
}