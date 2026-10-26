{lib}: let
  common = import ../personal-common.nix {inherit lib;};
in {
  settings = {
    inherit (common) domain;
    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
  };
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: common.webEndpoints instance // {app = common.appEndpoint instance;};
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/private/uptime-kuma";
    }
  ];
  validate = common.validate "uptime-kuma";
  activation = [["services" "uptime-kuma" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      services.uptime-kuma = {
        enable = true;
        settings = {
          HOST = common.bindAddress instance.settings.listenAddress;
          PORT = toString instance.settings.port;
        };
      };
      mnemosyne.dirs = ["/var/lib/private/uptime-kuma"];
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
