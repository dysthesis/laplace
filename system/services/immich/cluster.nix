{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;} // {inherit (common) domain;};
  endpointNames = ["app" "https" "http" "postgresql" "machine-learning"];
  endpoints = {instance, ...}:
    common.webEndpoints instance
    // {
      app = common.appEndpoint instance;
      postgresql = common.postgresEndpoint instance;
      machine-learning = {
        host = instance.host;
        protocol = "tcp";
        port = 3003;
        listenAddress = "localhost";
        scope = "loopback";
      };
    };
  resources = instance:
    [
      {
        kind = "path";
        value = toString instance.settings.mediaLocation;
      }
      {
        kind = "path";
        value = "/var/cache/immich";
      }
      {
        kind = "path";
        value = "/var/lib/redis-immich";
      }
      {
        kind = "uid";
        value = "997";
      }
    ]
    ++ common.postgresResources "immich";
  validate = {
    instance,
    cluster,
  }:
    common.validate "immich" {inherit instance cluster;}
    ++ [
      {
        assertion = (cluster.hosts.${instance.host} or null) != null && builtins.elem "photos" cluster.hosts.${instance.host}.storage;
        message = "immich requires a host with the photos storage capability for its media and model cache.";
      }
    ];
  activation = [["laplace" "services" "immich" "enable"] ["services" "immich" "enable"] ["services" "redis" "servers" "immich" "enable"]];
  project = {
    instance,
    cluster,
    hostName,
  }: {config, ...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.immich = {
        enable = true;
        inherit (instance.settings) mediaLocation port;
        listenAddress = common.bindAddress instance.settings.listenAddress;
        # Shared PostgreSQL uses one parent mount to prevent nested version-specific bind mounts.
        postgresqlPersistenceRoot =
          if (cluster.activeServices.miniflux or null) != null && cluster.activeServices.miniflux.host == instance.host
          then "/var/lib/postgresql"
          else config.services.postgresql.dataDir;
      };
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
