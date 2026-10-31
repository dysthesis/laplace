{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;} // {inherit (common) domain;};
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: common.webEndpoints instance // {app = common.appEndpoint instance;};
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/private/vikunja";
    }
  ];
  validate = common.validate "vikunja";
  activation = [["laplace" "services" "vikunja" "enable"] ["services" "vikunja" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.vikunja = {
        enable = true;
        inherit (instance.settings) port;
        # Upstream appends :port to address for service.interface.
        listenAddress = common.hostAddress instance.settings.listenAddress;
      };
      services.vikunja = {
        frontendScheme = "https";
        frontendHostname = instance.settings.domain;
      };
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "127.0.0.1" (common.appEndpoint instance);
    };
}
