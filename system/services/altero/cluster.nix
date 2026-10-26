{lib}: let
  common = import ../personal-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;};
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}:
    common.webEndpoints instance
    // {
      app = {
        host = instance.host;
        protocol = "tcp";
        port = instance.settings.port;
        listenAddress = "127.0.0.1";
        scope = "loopback";
      };
    };
  resources = instance: [
    {
      kind = "path";
      value = instance.settings.dataDir;
    }
    {
      kind = "path";
      value = "/var/backups/altero";
    }
    # The container's fixed identity owns the host-mounted attachment/database tree.
    {
      kind = "uid";
      value = "10001";
    }
  ];
  validate = common.validate "altero";
  activation = [["laplace" "services" "altero" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.altero = instance.settings // {enable = true;};
      laplace.services.caddy.virtualHosts.${instance.settings.domain}.extraConfig = ''
        tls {
          dns cloudflare {env.CF_API_TOKEN}
          resolvers 1.1.1.1
        }
        reverse_proxy 127.0.0.1:${toString instance.settings.port} {
          header_up X-Forwarded-For {remote_host}
        }
      '';
    };
}
