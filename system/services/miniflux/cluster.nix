{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = {
    inherit (common) domain sopsFile;
    port = lib.mkOption {
      type = lib.types.port;
      default = 8087;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    allowPrivateNetworks = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    useKarakeepBrowser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use the active colocated Karakeep Chromium endpoint for feed fetching.";
    };
  };
  endpointNames = ["app" "direct" "https" "http" "postgresql"];
  endpoints = {instance, ...}: let
    app = common.appEndpoint instance // {shared = "miniflux";};
  in
    common.webEndpoints instance
    // {
      inherit app;
      direct = app;
      postgresql = common.postgresEndpoint instance;
    };
  resources = _instance:
    [
      {
        kind = "path";
        value = "/var/lib/private/miniflux";
      }
    ]
    ++ common.postgresResources "miniflux";
  validate = {
    instance,
    cluster,
  }:
    common.validate "miniflux" {inherit instance cluster;}
    ++ [
      {
        assertion = !instance.enable || !instance.settings.useKarakeepBrowser || (cluster.services.karakeep != null && cluster.services.karakeep.enable && cluster.services.karakeep.host == instance.host);
        message = "miniflux with useKarakeepBrowser requires active karakeep on the same host.";
      }
    ];
  activation = [["laplace" "services" "miniflux" "enable"] ["services" "miniflux" "enable"]];
  project = {
    instance,
    cluster,
    hostName,
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.miniflux.enable = true;
      sops.secrets.miniflux_admin.sopsFile = instance.settings.sopsFile;
      services.miniflux.config =
        {
          # This deliberate direct-reader socket remains firewall-scoped by identity.
          LISTEN_ADDR = common.hostPort instance.settings.listenAddress instance.settings.port;
          BASE_URL = "https://${instance.settings.domain}";
          INTEGRATION_ALLOW_PRIVATE_NETWORKS =
            if instance.settings.allowPrivateNetworks
            then "1"
            else "0";
        }
        // lib.optionalAttrs instance.settings.useKarakeepBrowser {
          BROWSER_WEB_URL = "http://${cluster.endpoints.karakeep.browser.listenAddress}:${toString cluster.endpoints.karakeep.browser.port}";
        };
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "127.0.0.1" (common.appEndpoint instance);
    };
}
