{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;};
  endpointNames = ["app" "https" "http" "browser" "meilisearch"];
  endpoints = {instance, ...}:
    common.webEndpoints instance
    // {
      app = common.appEndpoint instance;
      browser = {
        host = instance.host;
        protocol = "tcp";
        port = instance.settings.browserPort;
        listenAddress = "127.0.0.1";
        scope = "loopback";
      };
      meilisearch = {
        host = instance.host;
        protocol = "tcp";
        port = instance.settings.searchPort;
        listenAddress = "localhost";
        scope = "loopback";
      };
    };
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/karakeep";
    }
    {
      kind = "path";
      value = "/var/lib/private/meilisearch";
    }
    {
      kind = "path";
      value = "/var/lib/private/karakeep-browser";
    }
    {
      kind = "path";
      value = "/var/cache/karakeep";
    }
    {
      kind = "path";
      value = "/var/cache/private/karakeep-browser";
    }
  ];
  validate = common.validate "karakeep";
  activation = [["laplace" "services" "karakeep" "enable"] ["services" "karakeep" "enable"] ["services" "meilisearch" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.karakeep =
        instance.settings
        // {
          enable = true;
          listenAddress = common.bindAddress instance.settings.listenAddress;
        };
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
