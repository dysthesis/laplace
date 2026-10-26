{lib}: let
  common = import ../personal-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;} // {inherit (common) domain;};
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: common.webEndpoints instance // {app = common.appEndpoint instance;};
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/silverbullet";
    }
  ];
  validate = common.validate "silverbullet";
  activation = [["laplace" "services" "silverbullet" "enable"] ["services" "silverbullet" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.silverbullet = {
        enable = true;
        inherit (instance.settings) port;
        listenAddress = common.bindAddress instance.settings.listenAddress;
      };
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
