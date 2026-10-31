{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = {
    inherit (common) domain;
    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    agentPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "Existing hub public SSH identity trusted by pull-mode machine agents.";
    };
  };
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: common.webEndpoints instance // {app = common.appEndpoint instance;};
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/private/beszel-hub";
    }
  ];
  validate = common.validate "beszel-hub";
  activation = [["laplace" "services" "beszel" "hub" "enable"] ["services" "beszel" "hub" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      # Agent identities and hub consumers are machine facilities projected centrally.
      laplace.services.beszel.hub = {
        enable = true;
        appUrl = "https://${instance.settings.domain}";
      };
      services.beszel.hub = {
        host = common.hostAddress instance.settings.listenAddress;
        inherit (instance.settings) port;
      };
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
