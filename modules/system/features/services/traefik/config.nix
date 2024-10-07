{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib.laplace) mkSubdomain;
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
          miniflux = mkSubdomain {
            service = "miniflux";
            subdomain = "rss";
          };

          forgejo = mkSubdomain {
            service = "forgejo";
            subdomain = "git";
          };

          searx = mkSubdomain {
            service = "searx";
            subdomain = "search";
          };

          openbooks = mkSubdomain {
            service = "openbooks";
            subdomain = "openbooks";
          };

          episteme =
            mkSubdomain {
              service = "episteme";
              subdomain = "notes";
            }
            // {
              middlewares = "strip-w1-prefix";
            };

          owntracks = mkSubdomain {
            service = "mosquitto";
            subdomain = "tracks";
          };

          comp6841 = mkSubdomain {
            service = "comp6841";
            subdomain = "comp6841";
            prefix = "/w1";
          };
        };

        middlewares = {
          strip-w1-prefix.stripPrefix.prefixes = ["/w1"];
        };

        services = {
          miniflux.loadBalancer.servers = [{url = "http://${config.services.miniflux.config.LISTEN_ADDR}";}];
          forgejo.loadBalancer.servers = [{url = "http://0.0.0.0:${toString config.services.forgejo.settings.server.HTTP_PORT}";}];
          searx.loadBalancer.servers = [{url = "http://${toString config.services.searx.settings.server.bind_address}:${toString config.services.searx.settings.server.port}";}];
          # TODO: Figure out how to not hardcode this
          openbooks.loadBalancer.servers = [{url = "http://127.0.0.1:8105";}];
          episteme.loadBalancer.servers = [{url = "http://localhost:8080";}];
          mosquitto.loadBalancer.servers = [{url = "http://127.0.0.1:8883";}];
          comp6841.loadBalancer.servers = [{url = "http://localhost:8081";}];
        };
      };
    };
  };
}
