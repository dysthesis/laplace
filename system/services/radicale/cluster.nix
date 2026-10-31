{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;} // {inherit (common) domain sopsFile;};
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: common.webEndpoints instance // {app = common.appEndpoint instance;};
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/radicale";
    }
  ];
  validate = common.validate "radicale";
  activation = [["laplace" "services" "radicale" "enable"] ["services" "radicale" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.radicale = {
        enable = true;
        inherit (instance.settings) port listenAddress;
      };
      sops.secrets.radicale_htpasswd.sopsFile = instance.settings.sopsFile;
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
